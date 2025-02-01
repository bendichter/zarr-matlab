classdef (Abstract) Store < handle
    %STORE Abstract base class for Zarr storage
    
    methods (Abstract)
        % Required methods that must be implemented by subclasses
        
        tf = isreadonly(obj)
        % Return true if store is read-only
        
        tf = supports_deletes(obj)
        % Return true if store supports delete operations
        
        set(obj, key, value)
        % Set data for key
        
        data = get(obj, key)
        % Get data for key, or empty if not found
        
        delete(obj, key)
        % Delete data for key if it exists
        
        tf = contains(obj, key)
        % Check if key exists
        
        keys = list(obj, prefix)
        % List all keys with optional prefix
    end
end
