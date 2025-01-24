classdef Array < handle
    % ARRAY N-dimensional array stored in chunked, compressed format
    %   Array provides the core functionality for Zarr arrays, supporting chunked
    %   storage, compression, and both v2 and v3 metadata formats.
    
    properties (SetAccess = private)
        shape           % Array shape (size in each dimension)
        dtype           % Data type
        chunks         % Chunk shape
        store          % Storage backend
        path           % Path within store
        read_only = false  % Whether array is read-only
        compressor     % Compression codec
        fill_value     % Fill value for uninitialized chunks
        order          % Memory layout ('C' or 'F')
        filters        % List of filters
        dimension_separator  % Dimension separator for chunk keys
        zarr_format    % Zarr format version (2 or 3)
    end
    
    properties (SetAccess = private)
        attrs          % Array attributes
        metadata      % ArrayMetadata instance
        grid          % ChunkGrid instance
        pipeline      % CodecPipeline instance
        indexer       % Indexer instance
    end
    
    methods
        function obj = Array(store, path, shape, dtype, varargin)
            % Create a new Array
            %
            % Parameters:
            %   store: zarr.core.Store
            %       Storage backend
            %   path: string
            %       Path within store
            %   shape: numeric vector
            %       Array shape
            %   dtype: string or numeric type
            %       Data type
            %   Optional parameters (name-value pairs):
            %     'chunks': numeric vector
            %         Chunk shape (default: automatic)
            %     'compressor': codec object
            %         Compression codec (default: zstd)
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
            %     'attributes': struct
            %         Initial attributes for the array
            
            % Input validation
            p = inputParser;
            p.addRequired('store', @(x) isa(x, 'zarr.core.Store'));
            p.addRequired('path', @ischar);
            p.addRequired('shape', @isnumeric);
            p.addRequired('dtype');
            p.addParameter('chunks', [], @(x) isempty(x) || isnumeric(x));
            p.addParameter('compressor', zarr.codecs.GzipCodec(), @(x) isempty(x) || isa(x, 'zarr.codecs.GzipCodec'));
            p.addParameter('fill_value', 0, @(x) true);  % Accept any value
            p.addParameter('order', 'C', @(x) ismember(x, {'C', 'F'}));
            p.addParameter('filters', {}, @iscell);
            p.addParameter('dimension_separator', '/', @(x) ismember(x, {'.', '/'}));
            p.addParameter('zarr_format', 3, @(x) ismember(x, [2, 3]));
            p.addParameter('attributes', struct(), @isstruct);
            
            p.parse(store, path, shape, dtype, varargin{:});
            
            % Validate shape
            shape = p.Results.shape(:)';  % Ensure row vector
            if ~isvector(shape)
                error('zarr:InvalidShape', 'Shape must be a vector');
            end
            if isempty(shape)
                error('zarr:InvalidShape', 'Shape cannot be empty');
            end
            
            % Store basic properties
            obj.store = p.Results.store;
            obj.path = p.Results.path;
            obj.shape = shape;
            obj.dtype = obj.parse_dtype(p.Results.dtype);
            obj.chunks = obj.normalize_chunks(p.Results.chunks);
            obj.compressor = p.Results.compressor;
            obj.fill_value = p.Results.fill_value;
            obj.order = p.Results.order;
            obj.filters = p.Results.filters;
            obj.dimension_separator = p.Results.dimension_separator;
            obj.zarr_format = p.Results.zarr_format;
            
            % Initialize helper objects
            obj.metadata = zarr.core.ArrayMetadata(obj.zarr_format, obj.shape, ...
                obj.chunks, obj.dtype, obj.compressor, obj.fill_value, ...
                obj.order, obj.filters, obj.dimension_separator);
            
            obj.grid = zarr.core.ChunkGrid(obj.shape, obj.chunks, ...
                obj.zarr_format, obj.dimension_separator);
            
            obj.pipeline = zarr.core.CodecPipeline(obj.compressor, obj.filters);
            
            obj.indexer = zarr.core.Indexer(obj.shape, obj.chunks, obj.dtype, ...
                obj.grid, obj.pipeline, obj.store, obj.path);
            
            % Initialize array
            obj.metadata.write(obj.store, obj.path);
            
            % Initialize attributes
            obj.attrs = zarr.core.Attributes(store, path, obj.zarr_format);
            
            % Set initial attributes if provided
            if ~isempty(fieldnames(p.Results.attributes))
                fields = fieldnames(p.Results.attributes);
                for i = 1:numel(fields)
                    obj.attrs.(fields{i}) = p.Results.attributes.(fields{i});
                end
            end
        end
        
        function dtype = parse_dtype(~, dtype_in)
            % Convert input dtype to MATLAB type
            if ischar(dtype_in)
                switch lower(dtype_in)
                    case {'double', 'float64'}
                        dtype = 'double';
                    case {'single', 'float32'}
                        dtype = 'single';
                    case {'int8', 'int16', 'int32', 'int64', ...
                          'uint8', 'uint16', 'uint32', 'uint64'}
                        dtype = dtype_in;
                    otherwise
                        error('zarr:InvalidDtype', ...
                            'Unsupported dtype: %s', dtype_in);
                end
            else
                % Assume it's already a valid MATLAB type
                dtype = dtype_in;
            end
        end
        
        function chunks = normalize_chunks(obj, chunks_in)
            % Normalize chunk shape, using automatic chunking if not specified
            if isempty(chunks_in)
                % Implement automatic chunk shape calculation
                chunks = obj.guess_chunks();
            else
                chunks = chunks_in(:)';  % Ensure row vector
                if length(chunks) ~= length(obj.shape)
                    error('zarr:InvalidChunks', ...
                        'Chunk shape must match array dimensionality');
                end
            end
        end
        
        function chunks = guess_chunks(obj)
            % Guess an appropriate chunk shape based on array shape and type
            % This is a simple implementation - could be made more sophisticated
            target_bytes = 1024 * 1024;  % Target 1MB chunks
            elem_size = obj.get_dtype_size();
            
            % Start with chunk shape matching array shape
            chunks = obj.shape;
            
            % Reduce chunk sizes until we're close to target size
            total_elements = prod(chunks);
            total_bytes = total_elements * elem_size;
            
            while total_bytes > target_bytes && any(chunks > 1)
                % Find largest dimension
                [~, dim] = max(chunks);
                % Halve it
                chunks(dim) = max(1, floor(chunks(dim)/2));
                % Recalculate size
                total_elements = prod(chunks);
                total_bytes = total_elements * elem_size;
            end
        end
        
        function bytes = get_dtype_size(obj)
            % Get size in bytes of the array's data type
            switch obj.dtype
                case 'double'
                    bytes = 8;
                case 'single'
                    bytes = 4;
                case {'int8', 'uint8'}
                    bytes = 1;
                case {'int16', 'uint16'}
                    bytes = 2;
                case {'int32', 'uint32'}
                    bytes = 4;
                case {'int64', 'uint64'}
                    bytes = 8;
                otherwise
                    error('zarr:UnsupportedDtype', ...
                        'Unsupported dtype: %s', obj.dtype);
            end
        end
        
        % Basic indexing
        function varargout = subsref(obj, s)
            % Handle array indexing
            switch s(1).type
                case '.'
                    % Handle property access
                    [varargout{1:nargout}] = builtin('subsref', obj, s);
                    return
                case '()'
                    % Handle array indexing
                    if numel(s) > 1
                        error('zarr:InvalidIndexing', ...
                            'Only simple indexing is supported');
                    end
                    varargout{1} = obj.indexer.get_selection(s(1).subs);
                    return
                otherwise
                    error('zarr:InvalidIndexing', ...
                        'Invalid indexing type');
            end
        end
        
        function obj = subsasgn(obj, s, value)
            % Handle array assignment
            
            % Check if read-only
            if obj.read_only
                error('zarr:ReadOnlyError', 'Array is read-only');
            end
            
            switch s(1).type
                case '.'
                    % Handle property assignment
                    obj = builtin('subsasgn', obj, s, value);
                    return
                case '()'
                    % Handle array assignment
                    if numel(s) > 1
                        error('zarr:InvalidIndexing', ...
                            'Only simple indexing is supported');
                    end
                    obj.indexer.set_selection(s(1).subs, value);
                    return
                otherwise
                    error('zarr:InvalidIndexing', ...
                        'Invalid indexing type');
            end
        end
        
        % Array information
        function disp(obj)
            % Display array information
            fprintf('Zarr array with properties:\n');
            fprintf('  shape: [%s]\n', strjoin(arrayfun(@num2str, obj.shape, 'UniformOutput', false), ' '));
            fprintf('  chunks: [%s]\n', strjoin(arrayfun(@num2str, obj.chunks, 'UniformOutput', false), ' '));
            fprintf('  dtype: %s\n', obj.dtype);
            fprintf('  compressor: %s\n', char(obj.compressor));
            fprintf('  order: %s\n', obj.order);
            fprintf('  format: v%d\n', obj.zarr_format);
        end
        
        function s = size(obj, dim)
            % Get array size
            if nargin < 2
                s = obj.shape;
            else
                if dim > numel(obj.shape)
                    s = 1;  % MATLAB convention for trailing dimensions
                else
                    s = obj.shape(dim);
                end
            end
        end
        
        function n = ndims(obj)
            % Get number of array dimensions
            n = numel(obj.shape);
            if n < 2
                n = 2;  % MATLAB convention: minimum 2 dimensions
            end
        end
        
        function obj = resize(obj, new_shape)
            % Resize array to new shape
            
            % Check if read-only
            if obj.read_only
                error('zarr:ReadOnlyError', 'Array is read-only');
            end
            
            % Validate new shape
            if ~isnumeric(new_shape) || ~isvector(new_shape)
                error('zarr:InvalidShape', ...
                    'Shape must be a numeric vector');
            end
            
            % Ensure row vector
            new_shape = new_shape(:)';
            
            % Check dimensionality
            if numel(new_shape) ~= numel(obj.shape)
                error('zarr:InvalidShape', ...
                    'New shape must have same number of dimensions');
            end
            
            % Get current and new chunk grid dimensions
            old_grid = ceil(obj.shape ./ obj.chunks);
            new_grid = ceil(new_shape ./ obj.chunks);
            
            % Delete chunks that are no longer needed
            if any(new_grid < old_grid)
                % Iterate over all chunks in the old grid
                for i = 1:prod(old_grid)
                    % Convert linear index to chunk coordinates
                    chunk_coords = cell(1, numel(obj.shape));
                    [chunk_coords{:}] = ind2sub(old_grid, i);
                    coords = cell2mat(chunk_coords);
                    
                    % Check if chunk is outside new grid
                    if any(coords > new_grid)
                        % Delete chunk if it exists
                        key = obj.grid.coords_to_key(coords, obj.path);
                        if obj.store.contains(key)
                            obj.store.delete(key);
                        end
                    end
                end
            end
            
            % Update shape
            obj.shape = new_shape;
            
            % Update metadata
            obj.metadata.write(obj.store, obj.path);
        end
    end
end
