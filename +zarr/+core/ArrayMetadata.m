classdef ArrayMetadata < handle
    % ARRAYMETADATA Metadata for Zarr arrays
    %   Handles metadata serialization and deserialization for both v2 and v3 formats
    
    properties
        zarr_format   % Zarr format version (2 or 3)
        shape         % Array shape
        chunks       % Chunk shape
        dtype        % Data type
        compressor   % Compression codec
        fill_value   % Fill value for uninitialized chunks
        order        % Memory layout ('C' or 'F')
        filters      % List of filters
        dimension_separator  % Dimension separator for chunk keys
    end
    
    methods
        function obj = ArrayMetadata(zarr_format, shape, chunks, dtype, compressor, ...
                fill_value, order, filters, dimension_separator)
            % Create new array metadata
            obj.zarr_format = zarr_format;
            obj.shape = shape;
            obj.chunks = chunks;
            obj.dtype = dtype;
            obj.compressor = compressor;
            obj.fill_value = fill_value;
            obj.order = order;
            obj.filters = filters;
            obj.dimension_separator = dimension_separator;
        end
        
        function write(obj, store, path)
            % Write metadata to store
            if obj.zarr_format == 2
                obj.write_v2(store, path);
            else
                obj.write_v3(store, path);
            end
        end
        
        function write_v2(obj, store, path)
            % Write v2 format metadata
            metadata = struct();
            metadata.zarr_format = 2;
            metadata.shape = obj.shape(:);  % Column vector for v2
            metadata.chunks = obj.chunks(:);  % Column vector for v2
            metadata.dtype = obj.get_dtype_str();
            config = obj.get_compressor_config();
            if ~isempty(config)
                config.name = config.id;  % Add name field for v2 format
            end
            metadata.compressor = config;
            metadata.fill_value = obj.fill_value;
            metadata.order = obj.order;
            metadata.filters = obj.filters;
            metadata.dimension_separator = obj.dimension_separator;
            
            % Store metadata
            store.set([path '/.zarray'], uint8(jsonencode(metadata)));
        end
        
        function write_v3(obj, store, path)
            % Write v3 format metadata
            metadata = struct();
            metadata.zarr_format = 3;
            metadata.node_type = 'array';
            metadata.shape = obj.shape(:);  % Column vector for v3
            metadata.data_type = obj.get_dtype_str();
            metadata.chunk_grid = struct(...
                'name', 'regular', ...
                'configuration', struct('chunk_shape', obj.chunks(:)));  % Column vector for v3
            
            % Create codec list
            codecs = {};
            if ~isempty(obj.compressor)
                config = obj.compressor.get_config();
                config.name = config.id;  % Add name field for v3 format
                codecs{end+1} = config;
            end
            if ~isempty(obj.filters)
                codecs = [codecs obj.filters];
            end
            metadata.codecs = codecs;
            
            metadata.fill_value = obj.fill_value;
            
            % Store metadata
            store.set([path '/zarr.json'], uint8(jsonencode(metadata)));
        end
        
        function dtype_str = get_dtype_str(obj)
            % Convert MATLAB type to Zarr dtype string
            switch obj.dtype
                case 'double'
                    dtype_str = '<f8';
                case 'single'
                    dtype_str = '<f4';
                case 'int8'
                    dtype_str = '<i1';
                case 'uint8'
                    dtype_str = '<u1';
                case 'int16'
                    dtype_str = '<i2';
                case 'uint16'
                    dtype_str = '<u2';
                case 'int32'
                    dtype_str = '<i4';
                case 'uint32'
                    dtype_str = '<u4';
                case 'int64'
                    dtype_str = '<i8';
                case 'uint64'
                    dtype_str = '<u8';
                otherwise
                    error('zarr:UnsupportedDtype', ...
                        'Unsupported dtype: %s', obj.dtype);
            end
        end
        
        function config = get_compressor_config(obj)
            % Get compressor configuration for v2 format
            if isempty(obj.compressor)
                config = [];
            else
                config = obj.compressor.get_config();
            end
        end
    end
end
