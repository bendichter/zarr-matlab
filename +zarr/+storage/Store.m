classdef Store < handle
    % STORE Base class for Zarr storage implementations
    %   Defines the interface that all storage implementations must follow.
    %   Provides common functionality and type checking.
    
    properties (Abstract, Constant)
        % Store capabilities
        supports_writes     % Does the store support writes?
        supports_deletes   % Does the store support deletes?
        supports_partial_writes  % Does the store support partial writes?
        supports_listing   % Does the store support listing?
    end
    
    properties (Access = protected)
        is_open = false    % Is the store open?
        read_only = false  % Is the store read-only?
    end
    
    methods
        function obj = Store(varargin)
            % Create a new Store instance
            %
            % Parameters:
            %   'read_only': logical
            %       Whether to open the store in read-only mode (default: false)
            
            p = inputParser;
            p.addParameter('read_only', false, @islogical);
            p.parse(varargin{:});
            
            obj.read_only = p.Results.read_only;
        end
        
        function open(obj)
            % Open the store
            %
            % Throws:
            %   Exception if store is already open
            
            if obj.is_open
                throw(MException('zarr:store:alreadyOpen', ...
                    'Store is already open'));
            end
            obj.is_open = true;
        end
        
        function ensure_open(obj)
            % Ensure store is open, opening it if necessary
            
            if ~obj.is_open
                obj.open();
            end
        end
        
        function close(obj)
            % Close the store
            
            obj.is_open = false;
        end
        
        function check_writable(obj)
            % Check if store is writable
            %
            % Throws:
            %   Exception if store is read-only
            
            if obj.read_only
                throw(MException('zarr:store:readOnly', ...
                    'Store is read-only'));
            end
        end
        
        function validateKey(~, key)
            % Validate key is a character array
            %
            % Parameters:
            %   key: any
            %       Value to validate
            %
            % Throws:
            %   Exception if key is not a character array
            
            if ~ischar(key)
                throw(MException('zarr:invalidType', ...
                    'Key must be a character array'));
            end
        end
        
        function validateValue(~, value)
            % Validate value is a uint8 array
            %
            % Parameters:
            %   value: any
            %       Value to validate
            %
            % Throws:
            %   Exception if value is not a uint8 array
            
            if ~isa(value, 'uint8')
                throw(MException('zarr:invalidType', ...
                    'Value must be uint8 array'));
            end
        end
        
        function keys = list_prefix(obj, prefix)
            % List keys with given prefix
            %
            % Parameters:
            %   prefix: char
            %       Key prefix to match
            %
            % Returns:
            %   keys: cell array
            %       Array of matching key strings
            
            if ~obj.supports_listing
                throw(MException('zarr:store:notSupported', ...
                    'Store does not support listing'));
            end
            
            obj.validateKey(prefix);
            
            % Get all keys and filter by prefix
            all_keys = obj.list();
            keys = {};
            for i = 1:numel(all_keys)
                if startsWith(all_keys{i}, prefix)
                    keys{end+1} = all_keys{i}; %#ok<AGROW>
                end
            end
            keys = keys(:);  % Ensure column vector
        end
        
        function keys = list_dir(obj, prefix)
            % List immediate keys under prefix
            %
            % Parameters:
            %   prefix: char
            %       Directory prefix to match
            %
            % Returns:
            %   keys: cell array
            %       Array of immediate child key strings
            
            if ~obj.supports_listing
                throw(MException('zarr:store:notSupported', ...
                    'Store does not support listing'));
            end
            
            obj.validateKey(prefix);
            
            % Remove trailing slash if present
            prefix = deblank(prefix);
            if ~isempty(prefix) && prefix(end) == '/'
                prefix = prefix(1:end-1);
            end
            
            % Get all keys with this prefix
            all_keys = obj.list_prefix(prefix);
            
            % Extract immediate children
            keys = {};
            prefix_len = length(prefix);
            if prefix_len > 0
                prefix_len = prefix_len + 1; % Account for separator
            end
            
            seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            
            for i = 1:numel(all_keys)
                key = all_keys{i};
                if prefix_len > 0
                    % Remove prefix and separator
                    key = key(prefix_len+1:end);
                end
                
                % Get first component
                parts = strsplit(key, '/');
                first = parts{1};
                
                % Add if not already seen
                if ~seen.isKey(first)
                    keys{end+1} = first; %#ok<AGROW>
                    seen(first) = true;
                end
            end
            keys = keys(:);  % Ensure column vector
        end
        
        function delete_dir(obj, prefix)
            % Delete all keys under prefix
            %
            % Parameters:
            %   prefix: char
            %       Directory prefix to delete
            
            if ~obj.supports_deletes
                throw(MException('zarr:store:notSupported', ...
                    'Store does not support deletes'));
            end
            if ~obj.supports_listing
                throw(MException('zarr:store:notSupported', ...
                    'Store does not support listing'));
            end
            
            obj.check_writable();
            obj.validateKey(prefix);
            
            % Ensure prefix ends with separator
            if ~isempty(prefix) && prefix(end) ~= '/'
                prefix = [prefix '/'];
            end
            
            % Delete all matching keys
            keys = obj.list_prefix(prefix);
            for i = 1:numel(keys)
                obj.delete(keys{i});
            end
        end
        
        function clear(obj)
            % Remove all keys from store
            
            if ~obj.supports_deletes
                throw(MException('zarr:store:notSupported', ...
                    'Store does not support deletes'));
            end
            if ~obj.supports_listing
                throw(MException('zarr:store:notSupported', ...
                    'Store does not support listing'));
            end
            
            obj.check_writable();
            obj.delete_dir('');
        end
        
        function tf = is_empty(obj, prefix)
            % Check if directory is empty
            %
            % Parameters:
            %   prefix: char
            %       Directory prefix to check
            %
            % Returns:
            %   tf: logical
            %       True if directory is empty
            
            if ~obj.supports_listing
                throw(MException('zarr:store:notSupported', ...
                    'Store does not support listing'));
            end
            
            obj.validateKey(prefix);
            
            % Ensure prefix ends with separator
            if ~isempty(prefix) && prefix(end) ~= '/'
                prefix = [prefix '/'];
            end
            
            % Check if any keys exist
            keys = obj.list_prefix(prefix);
            tf = isempty(keys);
        end
        
        function nbytes = getsize(obj, key)
            % Get size of value in bytes
            %
            % Parameters:
            %   key: char
            %       Key to get size for
            %
            % Returns:
            %   nbytes: int64
            %       Size in bytes
            %
            % Throws:
            %   Exception if key does not exist
            
            value = obj.get(key);
            if isempty(value)
                throw(MException('zarr:store:keyNotFound', ...
                    'Key not found: %s', key));
            end
            nbytes = int64(numel(value));
        end
        
        function nbytes = getsize_prefix(obj, prefix)
            % Get total size of all values under prefix
            %
            % Parameters:
            %   prefix: char
            %       Directory prefix to measure
            %
            % Returns:
            %   nbytes: int64
            %       Total size in bytes
            
            if ~obj.supports_listing
                throw(MException('zarr:store:notSupported', ...
                    'Store does not support listing'));
            end
            
            obj.validateKey(prefix);
            
            % Sum sizes of all values
            keys = obj.list_prefix(prefix);
            nbytes = int64(0);
            for i = 1:numel(keys)
                nbytes = nbytes + obj.getsize(keys{i});
            end
        end
    end
    
    methods (Abstract)
        % These methods must be implemented by subclasses
        
        set(obj, key, value)
        % Store value for key
        %
        % Parameters:
        %   key: char
        %       Store key
        %   value: uint8
        %       Value to store (must be uint8 array)
        
        value = get(obj, key)
        % Retrieve value for key
        %
        % Parameters:
        %   key: char
        %       Store key
        %
        % Returns:
        %   value: uint8
        %       Retrieved value, or empty if key does not exist
        
        tf = contains(obj, key)
        % Check if key exists in store
        %
        % Parameters:
        %   key: char
        %       Store key
        %
        % Returns:
        %   tf: logical
        %       True if key exists
        
        delete(obj, key)
        % Delete key from store
        %
        % Parameters:
        %   key: char
        %       Store key to delete
        
        keys = list(obj)
        % List all keys in store
        %
        % Returns:
        %   keys: cell array
        %       Array of key strings
    end
end
