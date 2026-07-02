function crc = crc32c(bytes)
%CRC32C CRC-32C (Castagnoli) checksum of a uint8 vector, returned as uint32.
%   Uses the MEX implementation when built (tools/build_mex.m); otherwise a
%   pure-MATLAB table-driven fallback.

persistent useMex
if isempty(useMex)
    useMex = ~isempty(which('zarr.internal.crc32c_mex'));
end
if useMex
    crc = zarr.internal.crc32c_mex(uint8(bytes(:)'));
    return
end

persistent T
if isempty(T)
    T = zeros(256, 1, 'uint32');
    poly = uint32(hex2dec('82F63B78'));
    for i = 0:255
        c = uint32(i);
        for k = 1:8
            if bitand(c, uint32(1))
                c = bitxor(bitshift(c, -1), poly);
            else
                c = bitshift(c, -1);
            end
        end
        T(i + 1) = c;
    end
end

crc = uint32(hex2dec('FFFFFFFF'));
b = uint32(bytes(:));
mask = uint32(255);
for i = 1:numel(b)
    crc = bitxor(bitshift(crc, -8), T(double(bitand(bitxor(crc, b(i)), mask)) + 1));
end
crc = bitxor(crc, uint32(hex2dec('FFFFFFFF')));
end
