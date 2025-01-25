classdef ArrayMetadata < handle
    % ARRAYMETADATA Handles metadata for Zarr arrays
    %   Manages reading and writing metadata in both v2 and v3 formats
    
    properties (SetAccess = private)
        zarr_format      % Zarr format version (2 or 3)
        shape           % Array shape
        chunks         % Chunk shape
        dtype          % Data type
        compressor     % Compression codec
        fill_value     % Fill value
        order          % Memory layout ('C' or 'F')
        filters        % List of filters
        dimension_separator  % Dimension separator (v2 only)
    end
    
    methods
        function obj = ArrayMetadata(zarr_format, shape, chunks, dtype, compressor, ...
                fill_value, order, filters, dimension_separator)
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
            % Write v2 metadata
            meta = struct();
            meta.zarr_format = 2;
            meta.shape = obj.shape;
            meta.chunks = obj.chunks;
            meta.dtype = obj.get_v2_dtype();
            if ~isempty(obj.compressor)
                meta.compressor = obj.compressor.get_config();
            else
                meta.compressor = [];
            end
            meta.fill_value = obj.fill_value;
            meta.order = obj.order;
            meta.filters = obj.filters;
            if ~isempty(obj.dimension_separator)
                meta.dimension_separator = obj.dimension_separator;
            end
            
            % Write to .zarray
            store.set([path '/.zarray'], uint8(jsonencode(meta)));
            
            % Initialize attributes if not already present
            if ~store.contains([path '/.zattrs'])
                store.set([path '/.zattrs'], uint8('{}'));
            end
        end
        
        function write_v3(obj, store, path)
            % Write v3 metadata
            meta = struct();
            meta.zarr_format = 3;
            meta.node_type = 'array';
            meta.shape = obj.shape;
            meta.data_type = obj.get_v3_dtype();
            
            % Add chunk grid configuration
            meta.chunk_grid = struct(...
                'name', 'regular', ...
                'configuration', struct(...
                    'chunk_shape', obj.chunks));
            
            % Add codec pipeline
            codecs = {};
            if ~isempty(obj.filters)
                codecs = [codecs obj.filters];
            end
            if ~isempty(obj.compressor)
                codecs{end+1} = obj.compressor.get_config();
            end
            meta.codecs = codecs;
            
            if ~isempty(obj.fill_value)
                meta.fill_value = obj.fill_value;
            end
            
            if strcmp(obj.order, 'F')
                meta.storage_transformers = {struct(...
                    'name', 'transpose', ...
                    'configuration', struct())};
            end
            
            % Write to zarr.json
            store.set([path '/zarr.json'], uint8(jsonencode(meta)));
            
            % Initialize attributes if not already present
            if ~store.contains([path '/attributes.json'])
                store.set([path '/attributes.json'], uint8('{}'));
            end
        end
        
        function dtype_str = get_v2_dtype(obj)
            % Convert MATLAB dtype to Zarr v2 dtype string
            switch obj.dtype
                case 'double'
                    dtype_str = '<f8';
                case 'single'
                    dtype_str = '<f4';
                case 'int8'
                    dtype_str = '|i1';
                case 'uint8'
                    dtype_str = '|u1';
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
        
        function dtype_str = get_v3_dtype(obj)
            % Convert MATLAB dtype to Zarr v3 dtype string
            switch obj.dtype
                case 'double'
                    dtype_str = 'float64';
                case 'single'
                    dtype_str = 'float32';
                case 'int8'
                    dtype_str = 'int8';
                case 'uint8'
                    dtype_str = 'uint8';
                case 'int16'
                    dtype_str = 'int16';
                case 'uint16'
                    dtype_str = 'uint16';
                case 'int32'
                    dtype_str = 'int32';
                case 'uint32'
                    dtype_str = 'uint32';
                case 'int64'
                    dtype_str = 'int64';
                case 'uint64'
                    dtype_str = 'uint64';
                otherwise
                    error('zarr:UnsupportedDtype', ...
                        'Unsupported dtype: %s', obj.dtype);
            end
        end
    end
end
