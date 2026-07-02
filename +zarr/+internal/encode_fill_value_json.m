function txt = encode_fill_value_json(v, info)
%ENCODE_FILL_VALUE_JSON MATLAB scalar -> JSON text for the fill_value field.

if info.zarrType == "string"
    if ismissing(v), v = ""; end
    txt = string(jsonencode(char(v)));
elseif info.zarrType == "variable_length_bytes"
    txt = """" + string(matlab.net.base64encode(uint8(v(:)'))) + """";
elseif info.isComplex
    txt = "[" + floatJson(real(double(v))) + "," + floatJson(imag(double(v))) + "]";
elseif info.zarrType == "bool"
    if logical(v), txt = "true"; else, txt = "false"; end
elseif startsWith(info.zarrType, "float")
    txt = floatJson(double(v));
elseif startsWith(info.zarrType, "uint")
    txt = string(sprintf('%u', uint64(v)));
else  % signed integers
    txt = string(sprintf('%d', int64(v)));
end
end

function s = floatJson(x)
if isnan(x)
    s = """NaN""";
elseif isinf(x)
    if x > 0, s = """Infinity"""; else, s = """-Infinity"""; end
else
    s = string(sprintf('%.17g', x));
end
end
