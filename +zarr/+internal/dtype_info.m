function info = dtype_info(dtype, config)
%DTYPE_INFO Map a Zarr v3 data_type to MATLAB type information.
%   dtype is the data_type name (string), or the decoded JSON value for
%   extension dtypes (a struct with fields name/configuration).
%   info fields:
%     zarrType    - zarr data_type name (string)
%     matlabClass - MATLAB class used to represent values in memory
%     itemsize    - bytes per element on disk
%     isComplex   - true for complex64/complex128
%     isFloat16   - true for float16 (represented as single in memory)
%     isVlen      - true for variable-length types (string, bytes)
%     config      - extension dtype configuration struct, or []
%     fields      - for zarrType "structured", a struct array (one entry
%                   per record field) with fields Name, Info (this same
%                   dtype_info struct, recursively), Offset (0-based byte
%                   offset within the record); [] otherwise
%
%   "structured" (a fixed-layout record/compound type) and its
%   "fixed_length_utf32" field sub-type are NOT part of the Zarr v3
%   specification -- they are unstable, unspecified extensions used by
%   zarr-python (a UnstableSpecificationWarning is raised when writing
%   them). Support here exists to read real-world files that use them
%   (e.g. some NWB Zarr v3 exports via hdmf-zarr); the on-disk
%   representation may change in a future zarr-python release.

if isstruct(dtype)
    config = struct();
    if isfield(dtype, 'configuration')
        config = dtype.configuration;
    end
    dtype = string(dtype.name);
elseif nargin < 2
    config = [];
end

dtype = string(dtype);
isComplex = false;
isFloat16 = false;
isVlen = false;

% numpy extension dtypes: int64 ticks of (scale_factor x unit); NaT = intmin.
% Represented in MATLAB as exact int64 (datetime is double-backed and would
% lose sub-microsecond precision for nanosecond timestamps).
if ismember(dtype, ["numpy.datetime64", "numpy.timedelta64"])
    if ~isstruct(config) || ~isfield(config, 'unit')
        error("zarr:InvalidMetadata", "%s requires a unit configuration.", dtype);
    end
    if ~isfield(config, 'scale_factor')
        config.scale_factor = 1;
    end
    info = struct( ...
        'zarrType', dtype, ...
        'matlabClass', "int64", ...
        'itemsize', 8, ...
        'isComplex', false, ...
        'isFloat16', false, ...
        'isVlen', false, ...
        'config', config, ...
        'fields', []);
    return
end

if dtype == "fixed_length_utf32"
    if ~isstruct(config) || ~isfield(config, 'length_bytes')
        error("zarr:InvalidMetadata", "fixed_length_utf32 requires a length_bytes configuration.");
    end
    info = struct( ...
        'zarrType', dtype, ...
        'matlabClass', "string", ...
        'itemsize', double(config.length_bytes), ...
        'isComplex', false, ...
        'isFloat16', false, ...
        'isVlen', false, ...
        'config', config, ...
        'fields', []);
    return
end

if dtype == "structured"
    if ~isstruct(config) || ~isfield(config, 'fields')
        error("zarr:InvalidMetadata", "structured requires a fields configuration.");
    end
    fields = structuredFieldInfo(config.fields);
    itemsize = 0;
    if ~isempty(fields)
        itemsize = fields(end).Offset + fields(end).Info.itemsize;
    end
    info = struct( ...
        'zarrType', dtype, ...
        'matlabClass', "struct", ...
        'itemsize', itemsize, ...
        'isComplex', false, ...
        'isFloat16', false, ...
        'isVlen', false, ...
        'config', config, ...
        'fields', fields);
    return
end

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
    'isVlen', isVlen, ...
    'config', [], ...
    'fields', []);
end

function fields = structuredFieldInfo(rawFields)
%STRUCTUREDFIELDINFO Normalize a "structured" dtype's fields configuration.
%   rawFields is jsondecode's output for a JSON list of [name, dtype]
%   pairs, where dtype is either a data_type name (char) or a nested
%   extension-dtype struct -- jsondecode returns this as a cell array of
%   2-element cell arrays (the pair elements are not type-uniform).

fields = struct('Name', {}, 'Info', {}, 'Offset', {});
offset = 0;
for i = 1:numel(rawFields)
    entry = rawFields{i};
    name = string(entry{1});
    subInfo = zarr.internal.dtype_info(entry{2});
    fields(end + 1) = struct('Name', name, 'Info', subInfo, 'Offset', offset); %#ok<AGROW>
    offset = offset + subInfo.itemsize;
end
end
