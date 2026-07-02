function v = hex2uint64(s)
%HEX2UINT64 Parse a hex string (no 0x prefix) to uint64 without precision loss.

s = char(lower(string(s)));
if isempty(s) || numel(s) > 16
    error("zarr:InvalidFillValue", "Invalid hex literal '%s'.", s);
end
v = uint64(0);
for c = s
    if c >= '0' && c <= '9'
        d = uint64(c - '0');
    elseif c >= 'a' && c <= 'f'
        d = uint64(c - 'a' + 10);
    else
        error("zarr:InvalidFillValue", "Invalid hex literal '%s'.", s);
    end
    v = bitor(bitshift(v, 4), d);
end
end
