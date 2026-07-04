function values = decode_fixed_utf32(bytes, info, n, endian)
%DECODE_FIXED_UTF32 Decode n consecutive fixed_length_utf32 elements.
%   bytes is a 1-by-(n*info.itemsize) uint8 vector; each info.itemsize-byte
%   element holds info.itemsize/4 UTF-32 code points, null-padded at the end
%   (matching numpy's fixed-length unicode ('U') convention). Returns an
%   n-by-1 string array with trailing null padding stripped.
%
%   Non-BMP code points (> U+FFFF) are not supported -- MATLAB char is
%   UTF-16, so representing them would require surrogate-pair handling this
%   function does not implement. Such input errors rather than silently
%   truncating to an incorrect BMP character.
%
%   "fixed_length_utf32" is not part of the Zarr v3 specification -- see
%   zarr.internal.dtype_info.

    arguments
        bytes (1,:) uint8
        info (1,1) struct
        n (1,1) double {mustBeNonnegative, mustBeInteger}
        endian (1,1) string {mustBeMember(endian, ["little", "big"])} = "little"
    end

    values = strings(n, 1);
    b = reshape(bytes, info.itemsize, n);
    for j = 1:n
        u32 = typecast(b(:, j), 'uint32');
        if endian == "big"
            u32 = swapbytes(u32);
        end
        lastNonZero = find(u32 ~= 0, 1, 'last');
        if isempty(lastNonZero)
            values(j) = "";
        else
            codePoints = double(u32(1:lastNonZero));
            if any(codePoints > 65535)
                error("zarr:UnsupportedValue", ...
                    "fixed_length_utf32 element contains a non-BMP code point (> U+FFFF), which is not supported.");
            end
            % char() preserves array shape rather than producing a 1-row
            % string of characters, so a column vector of code points must
            % be transposed to a row first -- otherwise string() reads each
            % row as a separate one-character string.
            values(j) = string(char(reshape(codePoints, 1, [])));
        end
    end
end
