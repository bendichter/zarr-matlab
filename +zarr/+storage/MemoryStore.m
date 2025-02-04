classdef MemoryStore < zarr.storage.Store
    % MEMORYSTORE In-memory store for Zarr arrays
    %   Implements an in-memory store using containers.Map for storage.
    %   Supports all basic store operations including partial reads/writes.
    
    properties (Access = private)
        store  % containers.Map to store the data
    end
    
    properties (Constant)
        % Store capabilities
        supports_writes = true
        supports_deletes = true
        supports_partial_writes = true
        supports_listing = true
    end
    
    methods
        function obj = MemoryStore(varargin)
            % Create a new MemoryStore instance
            %
            % Parameters:
            %   'read_only': logical
            %       Whether to open the store in read-only mode (default: false)
            
            % Call superclass constructor
            obj@zarr.storage.Store(varargin{:});
            
            % Initialize store
            obj.store = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.open();
        end
        
        function set(obj, key, value)
            % Store value for key
            %
            % Parameters:
            %   key: char
            %       Store key
            %   value: uint8
            %       Value to store (must be uint8 array)
            
            obj.check_writable();
            obj.ensure_open();
            obj.validateKey(key);
            obj.validateValue(value);
            
            obj.store(key) = value;
        end
        
        function value = get(obj, key)
            % Retrieve value for key
            %
            % Parameters:
            %   key: char
            %       Store key
            %
            % Returns:
            %   value: uint8
            %       Retrieved value, or empty if key does not exist
            
            obj.ensure_open();
            obj.validateKey(key);
            
            if obj.store.isKey(key)
                value = obj.store(key);
            else
                value = uint8([]);
            end
        end
        
        function tf = contains(obj, key)
            % Check if key exists in store
            %
            % Parameters:
            %   key: char
            %       Store key
            %
            % Returns:
            %   tf: logical
            %       True if key exists
            
            obj.ensure_open();
            obj.validateKey(key);
            
            tf = obj.store.isKey(key);
        end
        
        function delete(obj, key)
            % Delete key from store
            %
            % Parameters:
            %   key: char
            %       Store key to delete
            
            obj.check_writable();
            obj.ensure_open();
            obj.validateKey(key);
            
            if obj.store.isKey(key)
                remove(obj.store, key);
            end
        end
        
        function keys = list(obj)
            % List all keys in store
            %
            % Returns:
            %   keys: cell array
            %       Array of key strings
            
            obj.ensure_open();
            keys = obj.store.keys();
            keys = keys(:);  % Ensure column vector
        end
        
        function clear(obj)
            % Remove all keys from store
            
            obj.check_writable();
            obj.ensure_open();
            obj.store = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
        
        function str = char(obj)
            % Convert store to string representation
            %
            % Returns:
            %   str: char
            %       String representation
            
            str = sprintf('MemoryStore<%d keys>', obj.store.Count);
        end
    end
end
