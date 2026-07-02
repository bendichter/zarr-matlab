function s = mshape(zshape)
%MSHAPE MATLAB size vector for a Zarr shape.
%   Rank 0 -> [1 1] (scalar), rank 1 -> [n 1] (column vector), rank >= 2
%   -> the shape unchanged.

zshape = reshape(zshape, 1, []);
if isempty(zshape)
    s = [1 1];
elseif isscalar(zshape)
    s = [zshape 1];
else
    s = zshape;
end
end
