classdef ZlibCodec < zarr.codecs.Codec
    %ZLIBCODEC The "numcodecs.zlib" codec (raw zlib framing, RFC 1950).
    %   The format HDF5's deflate filter produces, and the codec name
    %   zarr-python's numcodecs wrapper registers — so stores using it are
    %   readable on both sides.

    properties (Constant)
        name = "numcodecs.zlib"
        kind = "bytes_bytes"
    end

    properties
        level (1,1) double {mustBeInteger, mustBeInRange(level, 0, 9)} = 1
    end

    methods
        function obj = ZlibCodec(level)
            if nargin > 0
                obj.level = level;
            end
        end

        function cfg = configuration(obj)
            cfg = struct('level', obj.level);
        end

        function out = encode(obj, bytes)
            out = zarr.internal.zlib_java('compress', bytes, obj.level);
        end

        function out = decode(~, bytes)
            out = zarr.internal.zlib_java('decompress', bytes);
        end
    end

    methods (Static)
        function obj = fromConfig(cfg)
            obj = zarr.codecs.ZlibCodec();
            if isfield(cfg, 'level'), obj.level = double(cfg.level); end
        end
    end
end
