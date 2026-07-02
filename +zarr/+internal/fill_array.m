function out = fill_array(fillValue, sz, info)
%FILL_ARRAY Array of size sz where every element is the fill value.
%   For variable_length_bytes the elements live in a cell array; everything
%   else is a direct repmat.

if info.zarrType == "variable_length_bytes"
    out = repmat({uint8(fillValue(:)')}, sz);
else
    out = repmat(fillValue, sz);
end
end
