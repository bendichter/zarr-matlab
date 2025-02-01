classdef ShuffleCodec < zarr.codecs.Codec
    %SHUFFLECODEC Byte shuffle codec for improved compression
    
    properties
        element_size  % Bytes per element (must match dtype)
    end
    
    methods
        function config = get_config(obj)  % public access to match superclass
            config = struct('id', 'shuffle', 'element_size', obj.element_size);
        end
        
        function obj = ShuffleCodec(element_size)
            if ~isscalar(element_size) || element_size < 1 || mod(element_size, 1) ~= 0
                error('MATLAB:validation:IncompatibleSize', 'element_size must be positive integer');
            end
            obj.element_size = element_size;
        end
        
        function data = decode(obj, data)
            data = obj.shuffle_unshuffle(data, 'unshuffle');
        end
        
        function data = encode(obj, data)
            data = obj.shuffle_unshuffle(data, 'shuffle');
        end
        
        function data = shuffle_unshuffle(obj, data, mode)
            orig_size = size(data);
            byte_view = typecast(data(:), 'uint8');
            
            % Reshape to [elements, element_size]
            byte_matrix = reshape(byte_view, obj.element_size, [])';
            
            % Transpose bytes for both shuffle and unshuffle
            % This matches numcodecs behavior where bytes are transposed
            shuffled = byte_matrix';
            
            % Convert back to original dtype
            data = typecast(shuffled(:), class(data));
            data = reshape(data, orig_size);
        end
    end
end
