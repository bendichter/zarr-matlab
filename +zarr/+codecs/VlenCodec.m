classdef (Abstract) VlenCodec < zarr.codecs.Codec
    %VLENCODEC Shared framing for vlen-utf8 / vlen-bytes (numcodecs format):
    %   uint32 LE item count, then per item: uint32 LE byte length + payload.

    properties (Constant)
        kind = "array_bytes"
    end

    methods (Abstract)
        b = itemToBytes(obj, item)   % element -> uint8 row
        item = bytesToItem(obj, b)   % uint8 row -> element
        A = emptyItems(obj, sz)      % preallocated element container
        A = setItem(obj, A, i, item)
        item = getItem(obj, A, i)
    end

    methods
        function cfg = configuration(~)
            cfg = [];
        end

        function txt = configJson(obj)
            txt = "{""name"":""" + obj.name + """,""configuration"":{}}";
        end

        function bytes = encode(obj, A, ~, shape)
            R = numel(shape);
            if R >= 2
                A = permute(A, R:-1:1);  % C order
            end
            n = prod(shape);
            pieces = cell(1, n + 1);
            pieces{1} = typecast(uint32(n), 'uint8');
            for i = 1:n
                b = obj.itemToBytes(obj.getItem(A, i));
                pieces{i + 1} = [typecast(uint32(numel(b)), 'uint8'), b];
            end
            bytes = [pieces{:}];
        end

        function A = decode(obj, bytes, ~, shape, ~)
            bytes = uint8(bytes(:)');
            n = prod(shape);
            if numel(bytes) < 4 || typecast(bytes(1:4), 'uint32') ~= n
                error("zarr:CodecError", ...
                    "%s: item count does not match chunk shape.", obj.name);
            end
            A = obj.emptyItems([n 1]);
            pos = 5;
            for i = 1:n
                if pos + 3 > numel(bytes)
                    error("zarr:CodecError", "%s: truncated chunk.", obj.name);
                end
                len = double(typecast(bytes(pos:pos + 3), 'uint32'));
                if pos + 3 + len > numel(bytes)
                    error("zarr:CodecError", "%s: truncated chunk.", obj.name);
                end
                A = obj.setItem(A, i, bytes(pos + 4:pos + 3 + len));
                pos = pos + 4 + len;
            end
            R = numel(shape);
            if R >= 2
                A = permute(reshape(A, flip(reshape(shape, 1, []))), R:-1:1);
            end
        end
    end
end
