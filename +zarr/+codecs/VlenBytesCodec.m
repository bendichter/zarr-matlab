classdef VlenBytesCodec < zarr.codecs.VlenCodec
    %VLENBYTESCODEC The "vlen-bytes" codec: cell arrays of uint8 rows.

    properties (Constant)
        name = "vlen-bytes"
    end

    methods
        function b = itemToBytes(~, item)
            b = uint8(item(:)');
        end

        function item = bytesToItem(~, b)
            item = uint8(b(:)');
        end

        function A = emptyItems(~, sz)
            A = repmat({uint8.empty(1, 0)}, sz);
        end

        function A = setItem(obj, A, i, b)
            A{i} = obj.bytesToItem(b);
        end

        function item = getItem(~, A, i)
            item = A{i};
        end
    end

    methods (Static)
        function obj = fromConfig(~)
            obj = zarr.codecs.VlenBytesCodec();
        end
    end
end
