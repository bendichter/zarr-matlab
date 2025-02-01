classdef DeltaCodec < zarr.codecs.Codec
    % DeltaCodec Encodes differences between consecutive elements
    
    properties
        dtype % Data type for encoding/decoding
    end
    
    methods
        function obj = DeltaCodec(dtype)
            %DELTACODEC Constructor
            % Validate and set dtype
            if nargin == 0
                error('DeltaCodec:MissingDtype', 'dtype parameter is required');
            end
            obj.dtype = dtype;
        end
        
        function encoded = encode(obj, data)
            %ENCODE Apply delta encoding
            % Convert input to specified dtype
            data = cast(data, obj.dtype);
            
            % Handle empty case
            if isempty(data)
                encoded = zeros(size(data), obj.dtype);
                return;
            end
            
            % Reshape to linear array for encoding
            original_size = size(data);
            data_linear = reshape(data, 1, []);
            
            % Delta encoding
            encoded = zeros(size(data_linear), obj.dtype);
            encoded(1) = data_linear(1);
            
            % Handle integer overflow for differences
            if isinteger(data_linear)
                % For each element, compute the difference considering overflow
                for i = 2:numel(data_linear)
                    prev = data_linear(i-1);
                    curr = data_linear(i);
                    
                    % Calculate difference considering data type range
                    if strcmp(obj.dtype, 'uint8')
                        encoded(i) = mod(int16(curr) - int16(prev), 256);
                    elseif strcmp(obj.dtype, 'int8')
                        diff_val = mod(int16(curr) - int16(prev) + 128, 256) - 128;
                        encoded(i) = cast(diff_val, 'int8');
                    else
                        encoded(i) = curr - prev;
                    end
                end
            else
                % For non-integer types, use regular diff
                encoded(2:end) = diff(data_linear);
            end
            
            % Restore original shape
            encoded = reshape(encoded, original_size);
        end
        
        function decoded = decode(obj, data)
            %DECODE Apply delta decoding
            % Convert input to specified dtype
            data = cast(data, obj.dtype);
            
            % Handle empty case
            if isempty(data)
                decoded = zeros(size(data), obj.dtype);
                return;
            end
            
            % Reshape to linear array for decoding
            original_size = size(data);
            data_linear = reshape(data, 1, []);
            
            % Cumulative sum decoding with overflow handling
            decoded_linear = zeros(size(data_linear), obj.dtype);
            decoded_linear(1) = data_linear(1);
            
            if isinteger(data_linear)
                % For each element, add the difference considering overflow
                for i = 2:numel(data_linear)
                    prev = decoded_linear(i-1);
                    diff_val = data_linear(i);
                    
                    % Calculate sum considering data type range
                    if strcmp(obj.dtype, 'uint8')
                        decoded_linear(i) = mod(int16(prev) + int16(diff_val), 256);
                    elseif strcmp(obj.dtype, 'int8')
                        sum_val = mod(int16(prev) + int16(diff_val) + 128, 256) - 128;
                        decoded_linear(i) = cast(sum_val, 'int8');
                    else
                        decoded_linear(i) = prev + diff_val;
                    end
                end
            else
                % For non-integer types, use regular cumsum
                decoded_linear = cumsum(data_linear);
            end
            
            % Restore original shape
            decoded = reshape(decoded_linear, original_size);
        end
        
        function config = get_config(obj)
            %GET_CONFIG Get codec configuration for serialization
            config = struct('id', 'delta', 'dtype', obj.dtype);
        end
    end
end
