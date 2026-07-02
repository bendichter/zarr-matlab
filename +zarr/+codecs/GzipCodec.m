classdef GzipCodec < zarr.codecs.Codec
    %GZIPCODEC The Zarr v3 "gzip" codec (RFC 1952), implemented via java.util.zip.

    properties (Constant)
        name = "gzip"
        kind = "bytes_bytes"
    end

    properties
        level (1,1) double {mustBeInteger, mustBeInRange(level, 0, 9)} = 5
    end

    methods
        function obj = GzipCodec(level)
            if nargin > 0
                obj.level = level;
            end
        end

        function cfg = configuration(obj)
            cfg = struct('level', obj.level);
        end

        function out = encode(obj, bytes)
            out = zarr.internal.gzip_java('compress', bytes, obj.level);
        end

        function out = decode(~, bytes)
            out = zarr.internal.gzip_java('decompress', bytes);
        end
    end

    methods (Static)
        function obj = fromConfig(cfg)
            if isfield(cfg, 'level')
                obj = zarr.codecs.GzipCodec(double(cfg.level));
            else
                obj = zarr.codecs.GzipCodec();
            end
        end
    end
end
