classdef Crc32cCodec < zarr.codecs.Codec
    %CRC32CCODEC The Zarr v3 "crc32c" checksum codec (4-byte little-endian suffix).

    properties (Constant)
        name = "crc32c"
        kind = "bytes_bytes"
    end

    methods
        function cfg = configuration(~)
            cfg = [];
        end

        function out = encode(~, bytes)
            bytes = uint8(bytes(:)');
            c = zarr.internal.crc32c(bytes);
            out = [bytes, typecast(c, 'uint8')];
        end

        function out = decode(~, bytes)
            bytes = uint8(bytes(:)');
            if numel(bytes) < 4
                error("zarr:CodecError", "crc32c: chunk shorter than checksum.");
            end
            stored = typecast(bytes(end - 3:end), 'uint32');
            out = bytes(1:end - 4);
            if zarr.internal.crc32c(out) ~= stored
                error("zarr:ChecksumError", ...
                    "crc32c checksum mismatch: stored data is corrupt.");
            end
        end
    end

    methods (Static)
        function obj = fromConfig(~)
            obj = zarr.codecs.Crc32cCodec();
        end
    end
end
