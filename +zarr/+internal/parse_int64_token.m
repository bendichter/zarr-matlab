function v = parse_int64_token(s, signed)
%PARSE_INT64_TOKEN Parse a decimal integer literal exactly into (u)int64.
%   jsondecode returns doubles, which lose precision beyond 2^53; metadata
%   parsing re-extracts the raw token and routes it here.

s = char(strtrim(string(s)));
neg = ~isempty(s) && s(1) == '-';
if neg
    s = s(2:end);
end
if isempty(s) || any(s < '0' | s > '9')
    error("zarr:InvalidFillValue", "Invalid integer literal '%s'.", s);
end
u = uint64(0);
for c = s
    u = u * 10 + uint64(c - '0');  % saturates only if the value itself overflows
end
if signed
    if neg
        if u == uint64(9223372036854775808)
            v = intmin('int64');
        elseif u > uint64(9223372036854775807)
            error("zarr:InvalidFillValue", "Integer literal out of int64 range.");
        else
            v = -int64(u);
        end
    else
        v = int64(u);
    end
else
    if neg
        error("zarr:InvalidFillValue", "Negative literal for unsigned type.");
    end
    v = u;
end
end
