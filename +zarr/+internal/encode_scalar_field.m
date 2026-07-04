function bytes = encode_scalar_field(value, fieldInfo, endian)
%ENCODE_SCALAR_FIELD Encode one "structured" record field into raw bytes.
%   Shared by zarr.internal.encode_structured (each record's fields) and,
%   recursively, by a nested "structured" or "fixed_length_utf32" field.

    arguments
        value
        fieldInfo (1,1) struct
        endian (1,1) string {mustBeMember(endian, ["little", "big"])} = "little"
    end

    if fieldInfo.zarrType == "structured"
        bytes = zarr.internal.encode_structured(value, fieldInfo, endian);
        return
    end
    if fieldInfo.zarrType == "fixed_length_utf32"
        bytes = zarr.internal.encode_fixed_utf32(string(value), fieldInfo, endian);
        return
    end

    switch true
        case fieldInfo.zarrType == "bool"
            raw = uint8(value);
        case fieldInfo.isFloat16
            raw = zarr.internal.single2half(single(value));
        case fieldInfo.isComplex
            raw = zeros(2, 1, char(fieldInfo.matlabClass));
            raw(1) = real(value);
            raw(2) = imag(value);
        otherwise
            raw = cast(value, char(fieldInfo.matlabClass));
    end
    if endian == "big" && fieldInfo.itemsize > 1
        raw = swapbytes(raw);
    end
    bytes = typecast(raw, 'uint8');
end
