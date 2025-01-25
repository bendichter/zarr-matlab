classdef Codec < handle
    % CODEC Base class for compression codecs
    %   All compression codecs must inherit from this class and implement
    %   the required methods.
    
    methods (Abstract)
        % Encode data for storage
        encoded = encode(obj, data)
        
        % Decode data from storage
        decoded = decode(obj, data)
        
        % Get codec configuration
        config = get_config(obj)
    end
    
    methods
        function str = char(obj)
            % Convert codec to string representation
            config = obj.get_config();
            if isempty(config)
                str = 'none';
            else
                str = jsonencode(config);
            end
        end
    end
end
