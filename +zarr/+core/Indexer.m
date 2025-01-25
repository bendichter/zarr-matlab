classdef Indexer < handle
    % INDEXER Handles array indexing operations for Zarr arrays
    %   Manages subsref and subsasgn operations for chunked arrays
    
    properties (SetAccess = private)
        shape      % Array shape
        chunks    % Chunk shape
        dtype     % Data type
        grid      % ChunkGrid instance
        pipeline  % CodecPipeline instance
        store     % Storage backend
        path      % Path within store
    end
    
    methods
        function obj = Indexer(shape, chunks, dtype, grid, pipeline, store, path)
            obj.shape = shape;
            obj.chunks = chunks;
            obj.dtype = dtype;
            obj.grid = grid;
            obj.pipeline = pipeline;
            obj.store = store;
            obj.path = path;
        end
        
        function result = get_selection(obj, subs)
            % Get data for array selection
            %
            % Parameters:
            %   subs: cell array
            %       Subscript indices
            %
            % Returns:
            %   result: array
            %       Selected data
            
            % Convert subscripts to linear indices for each dimension
            indices = obj.parse_subscripts(subs);
            
            % Calculate output size
            out_shape = cellfun(@numel, indices);
            
            % Initialize output array with correct shape
            result = zeros(out_shape, obj.dtype);
            
            % Convert indices to n-dimensional grid
            num_dims = numel(indices);
            [subs{1:num_dims}] = ndgrid(indices{:});
            
            % Get chunk coordinates
            [chunk_coords, chunk_idx] = obj.grid.get_chunk_coords(indices);
            
            % Create linear indices for result array
            result_size = cellfun(@numel, indices);
            result_linear = 1:prod(result_size);
            
            % Load each required chunk
            for i = 1:size(chunk_coords, 2)
                % Get chunk data
                coords = chunk_coords(:,i);
                chunk = obj.get_chunk(coords);
                
                % Find indices that map to this chunk
                chunk_mask = chunk_idx == i;
                
                % Calculate local indices within chunk
                chunk_starts = (coords - 1) .* obj.chunks + 1;
                
                % Get local indices for this chunk
                local_subs = cell(1, num_dims);
                for j = 1:num_dims
                    local_subs{j} = subs{j}(chunk_mask) - chunk_starts(j) + 1;
                end
                
                % Convert to linear indices and copy data
                local_linear = sub2ind(size(chunk), local_subs{:});
                result(result_linear(chunk_mask)) = chunk(local_linear);
            end
        end
        
        function set_selection(obj, subs, value)
            % Set data for array selection
            %
            % Parameters:
            %   subs: cell array
            %       Subscript indices
            %   value: array
            %       Data to assign
            
            % Convert subscripts to linear indices for each dimension
            indices = obj.parse_subscripts(subs);
            
            % Validate value size
            expected_size = cellfun(@numel, indices);
            if ~isequal(size(value), expected_size(:)')  % Compare with row vector
                error('zarr:InvalidValue', ...
                    'Value size does not match indexed region');
            end
            
            % Convert indices to n-dimensional grid
            num_dims = numel(indices);
            [subs{1:num_dims}] = ndgrid(indices{:});
            
            % Get chunk coordinates
            [chunk_coords, chunk_idx] = obj.grid.get_chunk_coords(indices);
            
            % Create linear indices for value array
            value_size = cellfun(@numel, indices);
            value_linear = 1:prod(value_size);
            
            % Update each affected chunk
            for i = 1:size(chunk_coords, 2)
                % Get chunk data
                coords = chunk_coords(:,i);
                chunk = obj.get_chunk(coords);
                
                % Find indices that map to this chunk
                chunk_mask = chunk_idx == i;
                
                % Calculate local indices within chunk
                chunk_starts = (coords - 1) .* obj.chunks + 1;
                
                % Get local indices for this chunk
                local_subs = cell(1, num_dims);
                for j = 1:num_dims
                    local_subs{j} = subs{j}(chunk_mask) - chunk_starts(j) + 1;
                end
                
                % Convert to linear indices and update chunk data
                local_linear = sub2ind(size(chunk), local_subs{:});
                chunk(local_linear) = value(value_linear(chunk_mask));
                
                % Write updated chunk
                obj.set_chunk(coords, chunk);
            end
        end
        
        function chunk = get_chunk(obj, chunk_coords)
            % Get chunk data from store
            %
            % Parameters:
            %   chunk_coords: numeric vector
            %       Chunk coordinates
            %
            % Returns:
            %   chunk: array
            %       Chunk data
            
            % Get store key for chunk
            key = obj.grid.coords_to_key(chunk_coords, obj.path);
            
            % Check if chunk exists
            if ~obj.store.contains(key)
                % Return fill value if chunk doesn't exist
                chunk_shape = obj.grid.get_chunk_shape(chunk_coords);
                chunk = zeros(chunk_shape(:)', obj.dtype);  % Row vector for chunk shape
                return
            end
            
            % Read and decode data
            bytes = obj.store.get(key);
            chunk_shape = obj.grid.get_chunk_shape(chunk_coords);
            chunk = obj.pipeline.decode(bytes, obj.dtype, chunk_shape(:)');  % Row vector for chunk shape
        end
        
        function set_chunk(obj, chunk_coords, chunk)
            % Set chunk data in store
            %
            % Parameters:
            %   chunk_coords: numeric vector
            %       Chunk coordinates
            %   chunk: array
            %       Chunk data
            
            % Validate chunk shape
            expected_shape = obj.grid.get_chunk_shape(chunk_coords);
            if ~isequal(size(chunk), expected_shape(:)')  % Compare with row vector
                error('zarr:InvalidChunkShape', ...
                    'Chunk shape does not match expected shape');
            end
            
            % Encode and store data
            bytes = obj.pipeline.encode(chunk);
            key = obj.grid.coords_to_key(chunk_coords, obj.path);
            obj.store.set(key, bytes);
        end
        
        function indices = parse_subscripts(obj, subs)
            % Convert subscripts to linear indices
            %
            % Parameters:
            %   subs: cell array
            %       Subscript indices
            %
            % Returns:
            %   indices: cell array
            %       Linear indices for each dimension
            
            % Validate number of subscripts
            if numel(subs) ~= numel(obj.shape)
                error('zarr:InvalidIndexing', ...
                    'Number of subscripts must match array dimensionality');
            end
            
            % Convert each subscript
            indices = cell(size(subs));
            for i = 1:numel(subs)
                if strcmp(subs{i}, ':')
                    indices{i} = 1:obj.shape(i);
                elseif isnumeric(subs{i})
                    indices{i} = subs{i};
                    if any(indices{i} < 1) || any(indices{i} > obj.shape(i))
                        error('zarr:IndexOutOfBounds', ...
                            'Index exceeds array bounds');
                    end
                else
                    error('zarr:InvalidIndexing', ...
                        'Invalid subscript type');
                end
            end
        end
    end
end
