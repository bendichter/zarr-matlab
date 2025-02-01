classdef ArrayMetadata < handle
    % ARRAYMETADATA Metadata for Zarr arrays
    %   Handles metadata serialization and deserialization for Zarr v2 format
    
    properties
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
        function obj = ArrayMetadata(shape, chunks, dtype, compressor, ...
                fill_value, order, filters, dimension_separator)
            % Create new array metadata
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
            metadata = struct();
            metadata.zarr_format = 2;  % Always write v2 format
            metadata.shape = obj.shape(:)';  % Row vector
            metadata.chunks = obj.chunks(:)';  % Row vector
            metadata.dtype = obj.get_dtype_str();
            config = obj.get_compressor_config();
            if ~isempty(config)
                config.name = config.id;  % Add name field
            end
            metadata.compressor = config;
            metadata.fill_value = obj.fill_value;
            metadata.order = obj.order;
            metadata.filters = obj.filters;
            metadata.dimension_separator = obj.dimension_separator;
            
            % Store metadata
            store.set([path '/.zarray'], uint8(jsonencode(metadata)));
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
            % Get compressor configuration
            if isempty(obj.compressor)
                config = [];
            else
                config = obj.compressor.get_config();
            end
        end
    end
end
