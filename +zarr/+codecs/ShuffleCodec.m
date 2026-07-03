classdef ShuffleCodec < zarr.codecs.Codec
    %SHUFFLECODEC The "numcodecs.shuffle" byte-shuffle codec.
    %   Groups the k-th byte of every element together, which typically
    %   improves compression of numeric data. Matches numcodecs.Shuffle
    %   (and HDF5's shuffle filter): trailing bytes that do not form a
    %   whole element are left unshuffled.

    properties (Constant)
        name = "numcodecs.shuffle"
        kind = "bytes_bytes"
    end

    properties
        elementsize (1,1) double {mustBeInteger, mustBePositive} = 4
    end

    methods
        function obj = ShuffleCodec(elementsize)
            if nargin > 0
                obj.elementsize = elementsize;
            end
        end

        function cfg = configuration(obj)
            cfg = struct('elementsize', obj.elementsize);
        end

        function out = encode(obj, bytes)
            bytes = uint8(bytes(:)');
            es = obj.elementsize;
            n = floor(numel(bytes) / es);
            head = reshape(reshape(bytes(1:n * es), es, n)', 1, []);
            out = [head, bytes(n * es + 1:end)];
        end

        function out = decode(obj, bytes)
            bytes = uint8(bytes(:)');
            es = obj.elementsize;
            n = floor(numel(bytes) / es);
            head = reshape(reshape(bytes(1:n * es), n, es)', 1, []);
            out = [head, bytes(n * es + 1:end)];
        end
    end

    methods (Static)
        function obj = fromConfig(cfg)
            obj = zarr.codecs.ShuffleCodec();
            if isfield(cfg, 'elementsize'), obj.elementsize = double(cfg.elementsize); end
        end
    end
end
