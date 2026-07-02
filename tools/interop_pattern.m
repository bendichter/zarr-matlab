function A = interop_pattern(shape, dtype)
%INTEROP_PATTERN MATLAB mirror of tools/interop_cases.py pattern().

info = zarr.internal.dtype_info(zarr.internal.normalize_dtype(dtype));
n = prod(shape);  % prod([]) == 1 for rank 0
base = mod(0:n - 1, 251);
cls = char(info.matlabClass);
if info.zarrType == "string"
    v = "s" + string(base);
elseif info.zarrType == "variable_length_bytes"
    v = arrayfun(@(x) uint8(0:mod(x, 5) - 1), base, 'UniformOutput', false);
elseif info.zarrType == "bool"
    v = logical(mod(base, 2));
elseif info.isComplex
    v = complex(cast(base / 4, cls), cast(base / 4 + 0.5, cls));
elseif startsWith(info.zarrType, "float")
    v = cast(base / 4, cls);
else
    v = cast(base, cls);
end
R = numel(shape);
if R >= 2
    A = permute(reshape(v, flip(reshape(shape, 1, []))), R:-1:1);  % C-order fill
elseif R == 1
    A = v(:);
else
    A = v;
end
end
