function info = dtype_info(dtype)
%DTYPE_INFO Map a Zarr v3 data_type string to MATLAB type information.
%   info fields:
%     zarrType    - zarr data_type name (string)
%     matlabClass - MATLAB class used to represent values in memory
%     itemsize    - bytes per element on disk
%     isComplex   - true for complex64/complex128
%     isFloat16   - true for float16 (represented as single in memory)
%     isVlen      - true for variable-length types (string, bytes)

dtype = string(dtype);
isComplex = false;
isFloat16 = false;
isVlen = false;
switch dtype
    case "bool",       cls = "logical"; itemsize = 1;
    case "int8",       cls = "int8";    itemsize = 1;
    case "int16",      cls = "int16";   itemsize = 2;
    case "int32",      cls = "int32";   itemsize = 4;
    case "int64",      cls = "int64";   itemsize = 8;
    case "uint8",      cls = "uint8";   itemsize = 1;
    case "uint16",     cls = "uint16";  itemsize = 2;
    case "uint32",     cls = "uint32";  itemsize = 4;
    case "uint64",     cls = "uint64";  itemsize = 8;
    case "float16",    cls = "single";  itemsize = 2; isFloat16 = true;
    case "float32",    cls = "single";  itemsize = 4;
    case "float64",    cls = "double";  itemsize = 8;
    case "complex64",  cls = "single";  itemsize = 8;  isComplex = true;
    case "complex128", cls = "double";  itemsize = 16; isComplex = true;
    case "string",                 cls = "string"; itemsize = NaN; isVlen = true;
    case "variable_length_bytes",  cls = "cell";   itemsize = NaN; isVlen = true;
    otherwise
        error("zarr:UnsupportedDataType", ...
            "Unsupported Zarr data type '%s'.", dtype);
end
info = struct( ...
    'zarrType', dtype, ...
    'matlabClass', string(cls), ...
    'itemsize', itemsize, ...
    'isComplex', isComplex, ...
    'isFloat16', isFloat16, ...
    'isVlen', isVlen);
end
