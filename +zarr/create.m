function array = create(varargin)
% CREATE Create a new Zarr array
%   ARRAY = CREATE(SHAPE, DTYPE) creates a new Zarr array with the specified
%   shape and data type, using default settings for all other parameters.
%
%   ARRAY = CREATE(STORE, SHAPE, DTYPE) creates a new Zarr array in the specified
%   store with the given shape and data type.
%
%   ARRAY = CREATE(..., 'Name', Value) specifies additional parameters using
%   name-value pairs:
%
%   Parameters:
%     'chunks': numeric vector
%         Chunk shape (default: automatic)
%     'compressor': codec object
%         Compression codec (default: blosc with lz4)
%     'fill_value': scalar
%         Fill value for uninitialized chunks
%     'order': char
%         Memory layout ('C' or 'F', default: 'C')
%     'filters': cell array
%         List of filters
%     'dimension_separator': char
%         Separator for chunk keys ('.' or '/', default: '/')
%     'zarr_format': numeric
%         Zarr format version (2 or 3, default: 3)
%     'path': string
%         Path within store (default: '')
%     'attributes': struct
%         User-defined attributes
%
%   Examples:
%     % Create a 1000x1000 double array with default settings
%     z = zarr.create([1000 1000], 'double');
%
%     % Create an array in a specific store with custom chunks
%     store = zarr.storage.FileStore('data.zarr');
%     z = zarr.create(store, [1000 1000], 'single', 'chunks', [100 100]);
%
%     % Create a compressed integer array with attributes
%     z = zarr.create([100 100], 'int32', ...
%         'compressor', zarr.codecs.BloscCodec('clevel', 5), ...
%         'attributes', struct('description', 'My array'));

    % Parse input arguments
    [store, shape, dtype, params] = parse_args(varargin{:});
    
    % Create array
    array = zarr.core.Array(store, params.path, shape, dtype, ...
        'chunks', params.chunks, ...
        'compressor', params.compressor, ...
        'fill_value', params.fill_value, ...
        'order', params.order, ...
        'filters', params.filters, ...
        'dimension_separator', params.dimension_separator, ...
        'zarr_format', params.zarr_format, ...
        'attributes', params.attributes);
end

function [store, shape, dtype, params] = parse_args(varargin)
    % Handle different call signatures
    if isnumeric(varargin{1})
        % create(shape, dtype, ...)
        store = zarr.storage.FileStore(tempname);
        shape = varargin{1}(:)';  % Ensure row vector
        dtype = varargin{2};
        args = varargin(3:end);
    else
        % create(store, shape, dtype, ...)
        store = varargin{1};
        shape = varargin{2}(:)';  % Ensure row vector
        dtype = varargin{3};
        args = varargin(4:end);
    end
    
    % Set default parameters
    params = struct();
    params.chunks = [];  % auto-chunking
    params.compressor = zarr.codecs.BloscCodec();  % default compression (matches Python Zarr)
    params.fill_value = [];
    params.order = 'C';
    params.filters = {};
    params.dimension_separator = '/';
    params.zarr_format = 3;
    params.path = '';
    params.attributes = struct();
    
    % Parse optional parameters
    if ~isempty(args)
        if mod(numel(args), 2) ~= 0
            error('MATLAB:InputParser:ArgumentValue', ...
                'Optional parameters must be specified as name-value pairs');
        end
        
        for i = 1:2:numel(args)
            name = args{i};
            value = args{i+1};
            
            switch lower(name)
                case 'chunks'
                    if ~isempty(value)
                        params.chunks = value(:)';  % Ensure row vector
                    else
                        params.chunks = value;
                    end
                case 'compressor'
                    params.compressor = value;
                case 'fill_value'
                    params.fill_value = value;
                case 'order'
                    params.order = value;
                case 'filters'
                    params.filters = value;
                case 'dimension_separator'
                    params.dimension_separator = value;
                case 'zarr_format'
                    params.zarr_format = value;
                case 'path'
                    params.path = value;
                case 'attributes'
                    params.attributes = value;
                otherwise
                    error('MATLAB:InputParser:UnmatchedParameter', ...
                        'Unknown parameter: %s', name);
            end
        end
    end
end
