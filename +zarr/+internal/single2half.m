function out = single2half(x)
%SINGLE2HALF Convert single to IEEE 754 binary16 bit patterns (uint16).
%   Round-to-nearest, ties-to-even, matching numpy's float32 -> float16 cast.

sz = size(x);
b = typecast(single(x(:)), 'uint32');
s = uint16(bitshift(bitand(b, uint32(hex2dec('80000000'))), -16));
e = double(bitand(bitshift(b, -23), uint32(255))) - 127;  % unbiased exponent
f = bitand(b, uint32(hex2dec('7FFFFF')));

out = zeros(numel(x), 1, 'uint16');

% NaN: preserve quiet NaN with some payload.
nanMask = e == 128 & f > 0;
out(nanMask) = bitor(s(nanMask), uint16(hex2dec('7E00')));

% Inf, or overflow after rounding (exponent > 15 always overflows; 15 with
% mantissa rounding overflow handled below via the add-carry trick).
infMask = e == 128 & f == 0;

% Normal / overflow-to-inf path: half exponent = e + 15 in [1, 30].
normMask = ~nanMask & ~infMask & e >= -14;
if any(normMask)
    eh = uint32(e(normMask) + 15);
    fh = f(normMask);
    % Assemble unrounded (exponent << 10 | mantissa >> 13), then round to
    % nearest even on the 13 dropped bits. Carry propagates naturally into
    % the exponent field, turning 0x7BFF+1 into 0x7C00 (Inf) as required.
    base = bitor(bitshift(eh, 10), bitshift(fh, -13));
    rem = bitand(fh, uint32(hex2dec('1FFF')));
    up = rem > 4096 | (rem == 4096 & bitand(base, uint32(1)) == 1);
    base = base + uint32(up);
    over = base >= uint32(hex2dec('7C00'));
    base(over) = uint32(hex2dec('7C00'));
    out(normMask) = bitor(s(normMask), uint16(base));
end
out(infMask) = bitor(s(infMask), uint16(hex2dec('7C00')));

% Subnormal / underflow path: |x| < 2^-14. Result mantissa = round(|x| * 2^24).
subMask = ~nanMask & ~infMask & e < -14;
if any(subMask)
    ax = abs(double(typecast(b(subMask), 'single')));
    m = ax * 2^24;
    fl = floor(m);
    fr = m - fl;
    up = fr > 0.5 | (fr == 0.5 & mod(fl, 2) == 1);
    m = uint32(fl) + uint32(up);
    m(m > 1024) = 1024;  % rounds up into smallest normal (0x0400) at most
    out(subMask) = bitor(s(subMask), uint16(m));
end

out = reshape(out, sz);
end
