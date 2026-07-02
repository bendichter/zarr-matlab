classdef ShardingCodec < zarr.codecs.Codec
    %SHARDINGCODEC The Zarr v3 "sharding_indexed" codec.
    %   An array->bytes codec that stores many small inner chunks inside one
    %   stored object (the shard), with a binary index locating each inner
    %   chunk. The outer chunk shape of the array is the SHARD shape;
    %   chunkShape here is the INNER chunk shape and must divide it evenly.
    %
    %   zarr.codecs.ShardingCodec(innerChunkShape, ...
    %       Codecs={...},              inner chunk codec chain (default: bytes)
    %       IndexCodecs={...},         index codec chain (default: bytes+crc32c)
    %       IndexLocation="end")       "start" or "end"

    properties (Constant)
        name = "sharding_indexed"
        kind = "array_bytes"
    end

    properties
        chunkShape (1,:) double
        codecs cell
        indexCodecs cell
        indexLocation (1,1) string {mustBeMember(indexLocation, ["start", "end"])} = "end"
    end

    properties (SetAccess = private)
        % Populated by bind() when the owning Pipeline is constructed.
        innerPipeline
        indexPipeline
        nChunks (1,:) double   % inner chunks per shard, per dimension
        indexLen (1,1) double  % encoded index size in bytes
    end

    methods
        function obj = ShardingCodec(chunkShape, opts)
            arguments
                chunkShape (1,:) double {mustBePositive, mustBeInteger}
                opts.Codecs cell = {zarr.codecs.BytesCodec()}
                opts.IndexCodecs cell = {zarr.codecs.BytesCodec(), zarr.codecs.Crc32cCodec()}
                opts.IndexLocation (1,1) string = "end"
            end
            obj.chunkShape = chunkShape;
            obj.codecs = zarr.internal.complete_codecs(opts.Codecs);
            obj.indexCodecs = zarr.internal.complete_codecs(opts.IndexCodecs);
            obj.indexLocation = opts.IndexLocation;
        end

        function cfg = configuration(obj)
            cfg = [];  % configJson is overridden; nothing needs the struct form
        end

        function txt = configJson(obj)
            inner = strings(1, numel(obj.codecs));
            for i = 1:numel(obj.codecs)
                inner(i) = obj.codecs{i}.configJson();
            end
            index = strings(1, numel(obj.indexCodecs));
            for i = 1:numel(obj.indexCodecs)
                index(i) = obj.indexCodecs{i}.configJson();
            end
            txt = "{""name"":""sharding_indexed"",""configuration"":{" + ...
                """chunk_shape"":[" + strjoin(compose("%d", obj.chunkShape), ",") + "]," + ...
                """codecs"":[" + strjoin(inner, ",") + "]," + ...
                """index_codecs"":[" + strjoin(index, ",") + "]," + ...
                """index_location"":""" + obj.indexLocation + """}}";
        end

        function obj = bind(obj, info, shardShape, fillValue)
            %BIND Precompute geometry and inner pipelines for a concrete array.
            shardShape = reshape(shardShape, 1, []);
            if isempty(shardShape)
                error("zarr:InvalidMetadata", "Sharding requires rank >= 1.");
            end
            if numel(obj.chunkShape) ~= numel(shardShape) || ...
                    any(mod(shardShape, obj.chunkShape) ~= 0)
                error("zarr:InvalidMetadata", ...
                    "Shard shape [%s] is not a multiple of inner chunk shape [%s].", ...
                    num2str(shardShape), num2str(obj.chunkShape));
            end
            obj.nChunks = shardShape ./ obj.chunkShape;
            obj.innerPipeline = zarr.codecs.Pipeline(obj.codecs, info, obj.chunkShape, fillValue);
            idxInfo = zarr.internal.dtype_info("uint64");
            obj.indexPipeline = zarr.codecs.Pipeline(obj.indexCodecs, idxInfo, [obj.nChunks 2]);
            obj.indexLen = zarr.codecs.ShardingCodec.indexByteLength(obj.indexCodecs, obj.nChunks);
        end

        function bytes = encode(obj, A, info, shardShape)
            obj.assertBound();
            total = prod(obj.nChunks);
            blobs = cell(1, total);
            offsets = zeros(total, 1, 'uint64');
            lens = zeros(total, 1, 'uint64');
            sentinel = intmax('uint64');
            fillChunk = zarr.internal.fill_array(obj.innerPipeline.fillValue, ...
                zarr.internal.mshape(obj.chunkShape), info);
            if obj.indexLocation == "start"
                pos = uint64(obj.indexLen);
            else
                pos = uint64(0);
            end
            for t = 0:total - 1
                coords = zarr.codecs.ShardingCodec.unravelC(t, obj.nChunks);
                subs = subsFor(coords .* obj.chunkShape, obj.chunkShape);
                chunk = reshape(A(subs{:}), zarr.internal.mshape(obj.chunkShape));
                if isequaln(chunk, fillChunk)
                    % All-fill inner chunks are not stored (missing-chunk sentinel).
                    blobs{t + 1} = uint8.empty(1, 0);
                    offsets(t + 1) = sentinel;
                    lens(t + 1) = sentinel;
                    continue
                end
                blob = obj.innerPipeline.encode(chunk);
                blobs{t + 1} = blob;
                offsets(t + 1) = pos;
                lens(t + 1) = uint64(numel(blob));
                pos = pos + uint64(numel(blob));
            end

            I = zeros(zarr.internal.mshape([obj.nChunks 2]), 'uint64');
            for t = 0:total - 1
                coords = zarr.codecs.ShardingCodec.unravelC(t, obj.nChunks);
                cSubs = num2cell(coords + 1);
                I(cSubs{:}, 1) = offsets(t + 1);
                I(cSubs{:}, 2) = lens(t + 1);
            end
            indexBytes = obj.indexPipeline.encode(I);

            if obj.indexLocation == "start"
                bytes = [indexBytes, blobs{:}];
            else
                bytes = [blobs{:}, indexBytes];
            end
        end

        function A = decode(obj, bytes, info, shardShape, fillValue)
            obj.assertBound();
            if nargin < 5
                fillValue = obj.innerPipeline.fillValue;
            end
            I = obj.decodeIndex(bytes);
            A = zarr.internal.fill_array(fillValue, zarr.internal.mshape(shardShape), info);
            sentinel = intmax('uint64');
            total = prod(obj.nChunks);
            for t = 0:total - 1
                coords = zarr.codecs.ShardingCodec.unravelC(t, obj.nChunks);
                cSubs = num2cell(coords + 1);
                off = I(cSubs{:}, 1);
                len = I(cSubs{:}, 2);
                if off == sentinel && len == sentinel
                    continue
                end
                chunk = obj.innerPipeline.decode(bytes(double(off) + 1:double(off + len)));
                subs = subsFor(coords .* obj.chunkShape, obj.chunkShape);
                A(subs{:}) = chunk;
            end
        end

        function I = decodeIndex(obj, indexOrShardBytes)
            %DECODEINDEX Decode the chunk index from a full shard OR from
            %   exactly indexLen bytes read at the right location.
            n = numel(indexOrShardBytes);
            if n < obj.indexLen
                error("zarr:CodecError", "Shard is smaller than its index.");
            end
            if obj.indexLocation == "start"
                ib = indexOrShardBytes(1:obj.indexLen);
            else
                ib = indexOrShardBytes(n - obj.indexLen + 1:n);
            end
            I = obj.indexPipeline.decode(ib);
        end
    end

    methods (Access = private)
        function assertBound(obj)
            if isempty(obj.innerPipeline)
                error("zarr:InternalError", ...
                    "ShardingCodec used outside a Pipeline (bind() not called).");
            end
        end
    end

    methods (Static)
        function obj = fromConfig(cfg)
            innerEntries = zarr.metadata.ArrayMetadata.asList(cfg.codecs);
            inner = cellfun(@zarr.codecs.from_config, innerEntries, 'UniformOutput', false);
            args = {reshape(cfg.chunk_shape, 1, []), 'Codecs', inner};
            if isfield(cfg, 'index_codecs')
                idxEntries = zarr.metadata.ArrayMetadata.asList(cfg.index_codecs);
                idx = cellfun(@zarr.codecs.from_config, idxEntries, 'UniformOutput', false);
                args = [args, {'IndexCodecs', idx}];
            end
            if isfield(cfg, 'index_location')
                args = [args, {'IndexLocation', string(cfg.index_location)}];
            end
            obj = zarr.codecs.ShardingCodec(args{:});
        end

        function len = indexByteLength(indexCodecs, nChunks)
            %INDEXBYTELENGTH Encoded index size; index codecs must be fixed-size.
            len = prod([nChunks 2]) * 8;
            for i = 1:numel(indexCodecs)
                c = indexCodecs{i};
                switch string(c.name)
                    case "bytes"       % no overhead
                    case "crc32c"
                        len = len + 4;
                    otherwise
                        error("zarr:UnsupportedCodec", ...
                            "Index codec '%s' does not have a fixed encoded size.", c.name);
                end
            end
        end

        function coords = unravelC(t, dims)
            %UNRAVELC 0-based linear index -> 0-based coords, C order (last fastest).
            R = numel(dims);
            coords = zeros(1, R);
            for d = R:-1:1
                coords(d) = mod(t, dims(d));
                t = floor(t / dims(d));
            end
        end
    end
end

function subs = subsFor(start0, count)
subs = arrayfun(@(s, c) s + 1:s + c, start0, count, 'UniformOutput', false);
if isscalar(subs)
    subs{end + 1} = 1;
end
end
