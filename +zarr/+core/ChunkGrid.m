classdef ChunkGrid < handle
    % CHUNKGRID Handles chunk coordinate operations for Zarr arrays
    %   Manages chunk coordinate calculations and key generation
    
    properties (SetAccess = private)
        shape               % Array shape
        chunks             % Chunk shape
        zarr_format        % Zarr format version
        dimension_separator % Dimension separator for v2
    end
    
    methods
        function obj = ChunkGrid(shape, chunks, zarr_format, dimension_separator)
            % Ensure row vectors
            obj.shape = shape(:)';
            obj.chunks = chunks(:)';
            obj.zarr_format = zarr_format;
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
            
            % Ensure row vector and convert to strings
            coords = chunk_coords(:)';
            coord_strs = arrayfun(@num2str, coords, 'UniformOutput', false);
            
            % Join with appropriate separator
            if obj.zarr_format == 2
                % v2 format: path/x.y.z
                key = strjoin(coord_strs, obj.dimension_separator);
                store_key = [path '/' key];
            else
                % v3 format: path/c/x/y/z
                store_key = [path '/c/' strjoin(coord_strs, '/')];
            end
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
            
            if obj.zarr_format == 2
                % v2 format: path/x.y.z
                % Remove path prefix
                prefix = [path '/'];
                if ~startsWith(store_key, prefix)
                    error('zarr:InvalidKey', ...
                        'Invalid chunk key format for v2');
                end
                key = store_key(length(prefix)+1:end);
                
                % Split on dimension separator
                coord_strs = strsplit(key, obj.dimension_separator);
            else
                % v3 format: path/c/x/y/z
                % Remove path and c prefix
                prefix = [path '/c/'];
                if ~startsWith(store_key, prefix)
                    error('zarr:InvalidKey', ...
                        'Invalid chunk key format for v3');
                end
                key = store_key(length(prefix)+1:end);
                
                % Split on forward slash
                coord_strs = strsplit(key, '/');
            end
            
            % Convert strings to numbers and ensure row vector
            chunk_coords = cellfun(@str2double, coord_strs);
            chunk_coords = chunk_coords(:)';
            
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
            
            % Ensure row vectors for output
            chunk_idx = chunk_idx(:)';
            chunk_coords = chunk_coords'; % Transpose to get dimensions as rows
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
            
            % Ensure row vector and calculate boundaries
            coords = chunk_coords(:)';
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
            
            % Ensure row vector and calculate shape
            coords = chunk_coords(:)';
            chunk_shape = min(obj.chunks, obj.shape - ...
                (coords - 1) .* obj.chunks);
        end
    end
end
