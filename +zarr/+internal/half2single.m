function out = half2single(h)
%HALF2SINGLE Convert IEEE 754 binary16 bit patterns (uint16) to single.

sz = size(h);
h = uint32(h(:));
s = bitshift(bitand(h, uint32(hex2dec('8000'))), 16);
e = bitand(bitshift(h, -10), uint32(31));
f = bitand(h, uint32(1023));

bits = zeros(numel(h), 1, 'uint32');

% Normal numbers: rebias exponent 15 -> 127.
n = e > 0 & e < 31;
bits(n) = bitor(s(n), bitor(bitshift(e(n) + 112, 23), bitshift(f(n), 13)));

% Inf / NaN.
i31 = e == 31;
bits(i31) = bitor(s(i31), bitor(uint32(hex2dec('7F800000')), bitshift(f(i31), 13)));

% Subnormals: value = f * 2^-24 (exactly representable in single).
sub = e == 0 & f > 0;
if any(sub)
    v = single(double(f(sub)) * 2^-24);
    bits(sub) = bitor(s(sub), typecast(v, 'uint32'));
end

% Zeros (e == 0, f == 0) keep just the sign bit.
z = e == 0 & f == 0;
bits(z) = s(z);

out = reshape(typecast(bits, 'single'), sz);
end
