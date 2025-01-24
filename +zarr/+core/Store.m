classdef (Abstract) Store < handle
    % STORE Abstract base class for Zarr storage backends
    %   Defines interface for storage backends used by Zarr arrays.
    %   Concrete implementations must override all abstract methods.
    
    methods (Abstract)
        % Check if key exists in store
        tf = contains(obj, key)
        
        % Get data for key
        data = get(obj, key)
        
        % Set data for key
        set(obj, key, value)
        
        % Delete key from store
        delete(obj, key)
        
        % List all keys in store
        keys = list(obj)
    end
    
    methods
        function rmdir(obj)
            % Remove store and all contents
            % Optional method - implementations may override
            error('zarr:NotImplementedError', ...
                'rmdir not implemented for this store type');
        end
    end
end
