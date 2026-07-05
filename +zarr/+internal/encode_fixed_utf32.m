function bytes = encode_fixed_utf32(values, info, endian)
%ENCODE_FIXED_UTF32 Encode n fixed_length_utf32 elements as raw bytes.
%   values is an n-by-1 (or 1-by-n) string array. Each element is encoded
%   as info.itemsize/4 UTF-32 code points, null-padded at the end to fill
%   info.itemsize bytes.
%
%   Non-BMP characters (> U+FFFF) are not supported -- MATLAB char is
%   UTF-16, so such a character appears as a surrogate pair of code units,
%   which this function would otherwise encode as two invalid UTF-32 code
%   points instead of one. Such input errors rather than encoding invalid
%   bytes.
%
%   "fixed_length_utf32" is not part of the Zarr v3 specification -- see
%   zarr.internal.dtype_info.

    arguments
        values string
        info (1,1) struct
        endian (1,1) string {mustBeMember(endian, ["little", "big"])} = "little"
    end

    values = reshape(values, [], 1);
    n = numel(values);
    nCodeUnits = info.itemsize / 4;
    bytes = zeros(1, n * info.itemsize, 'uint8');
    for j = 1:n
        chars = double(char(values(j)));
        if any(chars >= 55296 & chars <= 57343)
            error("zarr:UnsupportedValue", ...
                "String '%s' contains a non-BMP character (> U+FFFF), which is not supported.", values(j));
        end
        if numel(chars) > nCodeUnits
            error("zarr:ValueError", ...
                "String '%s' (%d characters) exceeds fixed_length_utf32 capacity of %d characters.", ...
                values(j), numel(chars), nCodeUnits);
        end
        u32 = zeros(1, nCodeUnits, 'uint32');
        u32(1:numel(chars)) = uint32(chars);
        if endian == "big"
            u32 = swapbytes(u32);
        end
        bytes((j - 1) * info.itemsize + 1 : j * info.itemsize) = typecast(u32, 'uint8');
    end
end
