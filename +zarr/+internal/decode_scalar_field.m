function value = decode_scalar_field(fieldBytes, fieldInfo, endian)
%DECODE_SCALAR_FIELD Decode one "structured" record field's raw bytes.
%   Shared by zarr.internal.decode_structured (each record's fields) and,
%   recursively, by a nested "structured" or "fixed_length_utf32" field.

    arguments
        fieldBytes (1,:) uint8
        fieldInfo (1,1) struct
        endian (1,1) string {mustBeMember(endian, ["little", "big"])} = "little"
    end

    if fieldInfo.zarrType == "structured"
        records = zarr.internal.decode_structured(fieldBytes, fieldInfo, 1, endian);
        value = records(1);
        return
    end
    if fieldInfo.zarrType == "fixed_length_utf32"
        values = zarr.internal.decode_fixed_utf32(fieldBytes, fieldInfo, 1, endian);
        value = values(1);
        return
    end

    b = fieldBytes(:);
    switch true
        case fieldInfo.zarrType == "bool"
            value = logical(b);
        case fieldInfo.isFloat16
            u = typecast(b, 'uint16');
            if endian == "big", u = swapbytes(u); end
            value = zarr.internal.half2single(u);
        case fieldInfo.isComplex
            raw = typecast(b, char(fieldInfo.matlabClass));
            if endian == "big", raw = swapbytes(raw); end
            value = complex(raw(1), raw(2));
        otherwise
            value = typecast(b, char(fieldInfo.matlabClass));
            if endian == "big" && fieldInfo.itemsize > 1
                value = swapbytes(value);
            end
    end
end
