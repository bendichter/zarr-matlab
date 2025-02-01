classdef ChunkGrid < handle
    % CHUNKGRID Handles chunk coordinate operations for Zarr arrays
    %   Manages chunk coordinate calculations and key generation
    
    properties (SetAccess = private)
        shape               % Array shape
        chunks             % Chunk shape
        dimension_separator % Dimension separator
    end
    
    methods
        function obj = ChunkGrid(shape, chunks, dimension_separator)
            % Keep as row vectors internally
            obj.shape = shape(:)';
            obj.chunks = chunks(:)';
            obj.dimension_separator = dimension_separator;
        end
        
        function store_key = coords_to_key(obj, chunk_coords, path)
            % Convert chunk coordinates to store key
            %
            % Parameters:
            %   chunk_coords: numeric vector
            %       Chunk coordinates
            %   path: string
            %       Path within store
            %
            % Returns:
            %   store_key: string
            %       Storage key for the chunk
            
            % Validate coordinates
            if numel(chunk_coords) ~= numel(obj.shape)
                error('zarr:InvalidChunkCoords', ...
                    'Chunk coordinates must match array dimensionality');
            end
            
            % Convert to strings
            coords = chunk_coords(:);
            coord_strs = arrayfun(@num2str, coords, 'UniformOutput', false);
            
            % Join with dimension separator
            key = strjoin(coord_strs, obj.dimension_separator);
            store_key = [path '/' key];
        end
        
        function chunk_coords = key_to_coords(obj, store_key, path)
            % Convert store key to chunk coordinates
            %
            % Parameters:
            %   store_key: string
            %       Storage key for the chunk
            %   path: string
            %       Path within store
            %
            % Returns:
            %   chunk_coords: numeric vector
            %       Chunk coordinates
            
            % Remove path prefix
            prefix = [path '/'];
            if ~startsWith(store_key, prefix)
                error('zarr:InvalidKey', ...
                    'Invalid chunk key format');
            end
            key = store_key(length(prefix)+1:end);
            
            % Split on dimension separator
            coord_strs = strsplit(key, obj.dimension_separator);
            
            % Convert strings to numbers and return as row vector
            chunk_coords = cellfun(@str2double, coord_strs);
            chunk_coords = chunk_coords(:)';  % Return as row vector
            
            % Validate dimensionality
            if numel(chunk_coords) ~= numel(obj.shape)
                error('zarr:InvalidKey', ...
                    'Chunk key dimensionality does not match array');
            end
        end
        
        function [chunk_coords, chunk_idx] = get_chunk_coords(obj, indices)
            % Get chunk coordinates for given indices
            %
            % Parameters:
            %   indices: cell array
            %       Array indices for each dimension
            %
            % Returns:
            %   chunk_coords: matrix
            %       Unique chunk coordinates
            %   chunk_idx: vector
            %       Index mapping points to chunks
            
            % Get chunk coordinates for each index
            num_dims = numel(indices);
            sizes = cellfun(@numel, indices);
            [subs{1:num_dims}] = ndgrid(indices{:});
            
            % Calculate chunk coordinates for each point
            chunk_coords = zeros(numel(subs{1}), num_dims);
            for i = 1:num_dims
                chunk_coords(:,i) = ceil(subs{i}(:) ./ obj.chunks(i));
            end
            
            % Get unique chunk coordinates
            [chunk_coords, ~, chunk_idx] = unique(chunk_coords, 'rows');
            
            % Return chunk_coords as columns, chunk_idx as row vector
            chunk_coords = chunk_coords';
            chunk_idx = chunk_idx(:)';  % Return as row vector
        end
        
        function local_indices = get_local_indices(obj, global_indices, chunk_coords)
            % Get local indices within a chunk
            %
            % Parameters:
            %   global_indices: cell array
            %       Global array indices
            %   chunk_coords: vector
            %       Chunk coordinates
            %
            % Returns:
            %   local_indices: cell array
            %       Local indices within chunk
            
            % Calculate boundaries
            coords = chunk_coords(:);
            chunk_starts = (coords - 1) .* obj.chunks + 1;
            chunk_ends = min(chunk_starts + obj.chunks - 1, obj.shape);
            
            % Initialize output
            local_indices = cell(size(global_indices));
            
            % For each dimension
            for i = 1:numel(global_indices)
                % Get indices for this dimension
                global_idx = global_indices{i}(:);
                
                % Convert to local indices
                local_idx = global_idx - chunk_starts(i) + 1;
                
                % Filter indices to only include those within chunk bounds
                valid_mask = local_idx >= 1 & local_idx <= (chunk_ends(i) - chunk_starts(i) + 1);
                local_indices{i} = local_idx(valid_mask);
            end
        end
        
        function chunk_shape = get_chunk_shape(obj, chunk_coords)
            % Get shape of chunk at given coordinates
            %
            % Parameters:
            %   chunk_coords: vector
            %       Chunk coordinates
            %
            % Returns:
            %   chunk_shape: vector
            %       Shape of chunk
            
            % Calculate shape for each dimension
            coords = chunk_coords(:)';  % Convert to row vector
            chunk_starts = (coords - 1) .* obj.chunks;
            chunk_ends = min(chunk_starts + obj.chunks, obj.shape);
            chunk_shape = chunk_ends - chunk_starts;
            
            % Return as row vector
            chunk_shape = chunk_shape(:)';
        end
    end
end
