classdef CodecPipeline < handle
    % CODECPIPELINE Handles compression and filter pipeline for Zarr arrays
    %   Manages encoding and decoding of chunk data through compression and filters
    
    properties (SetAccess = private)
        compressor  % Compression codec
        filters    % List of filters
    end
    
    methods
        function obj = CodecPipeline(compressor, filters)
            obj.compressor = compressor;
            obj.filters = filters;
        end
        
        function bytes = encode(obj, data)
            % Encode data through filters and compression
            %
            % Parameters:
            %   data: array
            %       Input data
            %
            % Returns:
            %   bytes: uint8 vector
            %       Encoded bytes
            
            % Apply filters in order
            filtered = data;
            for i = 1:numel(obj.filters)
                filtered = obj.filters{i}.encode(filtered);
            end
            
            % Convert to bytes
            bytes = typecast(filtered(:), 'uint8');
            
            % Compress
            if ~isempty(obj.compressor)
                bytes = obj.compressor.encode(bytes);
            end
        end
        
        function data = decode(obj, bytes, dtype, chunk_shape)
            % Decode bytes through decompression and filters
            %
            % Parameters:
            %   bytes: uint8 vector
            %       Input bytes
            %   dtype: string
            %       Data type for output array
            %   chunk_shape: vector
            %       Shape of output chunk
            %
            % Returns:
            %   data: array
            %       Decoded data
            
            % Decompress
            if ~isempty(obj.compressor)
                decompressed = obj.compressor.decode(bytes);
            else
                decompressed = bytes;
            end
            
            % Convert to array
            data = reshape(typecast(decompressed, dtype), chunk_shape);
            
            % Apply filters in reverse order
            for i = numel(obj.filters):-1:1
                data = obj.filters{i}.decode(data);
            end
        end
    end
end
