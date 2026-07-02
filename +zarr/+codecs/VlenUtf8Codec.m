classdef VlenUtf8Codec < zarr.codecs.VlenCodec
    %VLENUTF8CODEC The "vlen-utf8" codec: string arrays <-> UTF-8 items.

    properties (Constant)
        name = "vlen-utf8"
    end

    methods
        function b = itemToBytes(~, item)
            if ismissing(item)
                item = "";
            end
            b = unicode2native(char(item), 'UTF-8');
            if isempty(b)
                b = uint8.empty(1, 0);
            end
        end

        function item = bytesToItem(~, b)
            if isempty(b)
                item = "";
            else
                item = string(native2unicode(uint8(b(:)'), 'UTF-8'));
            end
        end

        function A = emptyItems(~, sz)
            A = strings(sz);
        end

        function A = setItem(obj, A, i, b)
            A(i) = obj.bytesToItem(b);
        end

        function item = getItem(~, A, i)
            item = A(i);
        end
    end

    methods (Static)
        function obj = fromConfig(~)
            obj = zarr.codecs.VlenUtf8Codec();
        end
    end
end
