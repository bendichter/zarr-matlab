classdef Attributes < handle
    % ATTRIBUTES Zarr array and group attributes
    %   Provides access to metadata attributes stored in .zattrs (v2) or
    %   attributes.json (v3) files.
    
    properties (Access = private)
        store       % Storage backend
        path        % Path within store
        format      % Zarr format version (2 or 3)
        cache       % Cached attributes
    end
    
    methods
        function obj = Attributes(store, path, format)
            % Create new Attributes instance
            %
            % Parameters:
            %   store: zarr.core.Store
            %       Storage backend
            %   path: string
            %       Path within store
            %   format: numeric
            %       Zarr format version (2 or 3)
            
            obj.store = store;
            obj.path = path;
            obj.format = format;
            obj.cache = struct();
            
            % Load initial attributes
            obj.read_attributes();
        end
        
        function value = subsref(obj, s)
            % Get attribute value
            %
            % Parameters:
            %   s: struct array
            %       Indexing information
            %
            % Returns:
            %   value: any
            %       Attribute value
            
            switch s(1).type
                case '.'
                    % Get attribute by name
                    name = s(1).subs;
                    if ~isfield(obj.cache, name)
                        error('zarr:AttributeError', ...
                            'Attribute not found: %s', name);
                    end
                    value = obj.cache.(name);
                    
                    % Handle nested references
                    if numel(s) > 1
                        value = subsref(value, s(2:end));
                    end
                otherwise
                    error('zarr:InvalidIndexing', ...
                        'Invalid attribute indexing');
            end
        end
        
        function obj = subsasgn(obj, s, value)
            % Set attribute value
            %
            % Parameters:
            %   s: struct array
            %       Indexing information
            %   value: any
            %       Value to set
            %
            % Returns:
            %   obj: Attributes
            %       Reference to attributes object
            
            switch s(1).type
                case '.'
                    % Set attribute by name
                    name = s(1).subs;
                    if numel(s) > 1
                        % Handle nested assignment
                        if ~isfield(obj.cache, name)
                            obj.cache.(name) = struct();
                        end
                        obj.cache.(name) = subsasgn(obj.cache.(name), ...
                            s(2:end), value);
                    else
                        % Direct assignment
                        obj.cache.(name) = value;
                    end
                    
                    % Write updated attributes
                    obj.write_attributes();
                otherwise
                    error('zarr:InvalidIndexing', ...
                        'Invalid attribute indexing');
            end
        end
        
        function names = keys(obj)
            % Get list of attribute names
            %
            % Returns:
            %   names: cell array
            %       List of attribute names
            
            names = fieldnames(obj.cache);
        end
        
        function tf = isKey(obj, name)
            % Check if attribute exists
            %
            % Parameters:
            %   name: string
            %       Attribute name
            %
            % Returns:
            %   tf: logical
            %       True if attribute exists
            
            tf = isfield(obj.cache, name);
        end
        
        function remove(obj, name)
            % Remove attribute
            %
            % Parameters:
            %   name: string
            %       Attribute name to remove
            
            if ~isfield(obj.cache, name)
                error('zarr:AttributeError', ...
                    'Attribute not found: %s', name);
            end
            
            obj.cache = rmfield(obj.cache, name);
            obj.write_attributes();
        end
        
        function clear(obj)
            % Remove all attributes
            
            obj.cache = struct();
            obj.write_attributes();
        end
        
        function attrs = asdict(obj)
            % Get all attributes as struct
            %
            % Returns:
            %   attrs: struct
            %       Copy of all attributes
            
            attrs = obj.cache;
        end
    end
    
    methods (Access = private)
        function read_attributes(obj)
            % Read attributes from store
            
            % Get attributes file path
            if obj.format == 2
                attrs_path = [obj.path '/.zattrs'];
            else
                attrs_path = [obj.path '/attributes.json'];
            end
            
            % Read and parse attributes
            if obj.store.contains(attrs_path)
                json_str = char(obj.store.get(attrs_path));
                obj.cache = jsondecode(json_str);
            else
                % Initialize empty attributes
                obj.cache = struct();
            end
        end
        
        function write_attributes(obj)
            % Write attributes to store
            
            % Convert to JSON
            json_str = jsonencode(obj.cache);
            
            % Get attributes file path
            if obj.format == 2
                attrs_path = [obj.path '/.zattrs'];
            else
                attrs_path = [obj.path '/attributes.json'];
            end
            
            % Write to store
            obj.store.set(attrs_path, uint8(json_str));
        end
    end
end
