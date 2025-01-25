classdef Group < handle
    % GROUP Hierarchical group of arrays and other groups
    %   Group provides hierarchical organization in Zarr, similar to HDF5 groups.
    %   It supports both v2 and v3 formats and allows for nested groups and arrays.
    
    properties (SetAccess = private)
        store          % Storage backend
        path           % Path within store
        read_only      % Whether group is read-only
        zarr_format   % Zarr format version (2 or 3)
    end
    
    properties (Access = private)
        attrs_store    % Store for attributes
    end
    
    properties (Dependent)
        attrs  % Group attributes
    end
    
    methods
        function attrs = get.attrs(obj)
            % Get group attributes
            if obj.zarr_format == 2
                % For v2, check .zattrs file
                if obj.store.contains([obj.path '/.zattrs'])
                    json_bytes = obj.store.get([obj.path '/.zattrs']);
                    if isempty(json_bytes)
                        attrs = struct();
                    else
                        attrs = jsondecode(char(json_bytes));
                        % Preserve cell array orientation for tags
                        if isfield(attrs, 'tags') && iscell(attrs.tags)
                            attrs.tags = reshape(attrs.tags, 1, []);
                        end
                    end
                else
                    attrs = struct();
                end
            else
                % For v3, attributes are in zarr.json
                if obj.store.contains([obj.path '/zarr.json'])
                    json_bytes = obj.store.get([obj.path '/zarr.json']);
                    if isempty(json_bytes)
                        attrs = struct();
                    else
                        metadata = jsondecode(char(json_bytes));
                        if isfield(metadata, 'attributes')
                            attrs = metadata.attributes;
                            % Preserve cell array orientation for tags
                            if isfield(attrs, 'tags') && iscell(attrs.tags)
                                attrs.tags = reshape(attrs.tags, 1, []);
                            end
                        else
                            attrs = struct();
                        end
                    end
                else
                    attrs = struct();
                end
            end
        end
        
        function obj = Group(store, path, varargin)
            % Create a new Group
            %
            % Parameters:
            %   store: zarr.core.Store
            %       Storage backend
            %   path: string
            %       Path within store
            %   Optional parameters (name-value pairs):
            %     'zarr_format': numeric
            %         Zarr format version (2 or 3, default: 3)
            %     'attributes': struct
            %         Group attributes
            
            % Input validation
            p = inputParser;
            p.addRequired('store', @(x) isa(x, 'zarr.core.Store'));
            p.addRequired('path', @ischar);
            p.addParameter('zarr_format', 3, @(x) ismember(x, [2, 3]));
            p.addParameter('attributes', struct(), @isstruct);
            
            p.parse(store, path, varargin{:});
            
            % Store properties
            obj.store = p.Results.store;
            obj.path = p.Results.path;
            obj.zarr_format = p.Results.zarr_format;
            obj.read_only = obj.store.isreadonly();
            
            % Initialize attributes store
            obj.attrs_store = struct();
            if ~isempty(fieldnames(p.Results.attributes))
                obj.attrs_store = p.Results.attributes;
            end
            
            % Initialize group
            obj.init_group();
        end
        
        function init_group(obj)
            % Initialize group metadata and storage
            
            % Create metadata based on format version
            if obj.zarr_format == 2
                obj.init_v2();
            else
                obj.init_v3();
            end
        end
        
        function init_v2(obj)
            % Initialize group with v2 format
            if ~obj.store.contains([obj.path '/.zgroup'])
                % Create .zgroup metadata file
                metadata = struct();
                metadata.zarr_format = 2;
                
                % Store metadata
                obj.store.set([obj.path '/.zgroup'], uint8(jsonencode(metadata)));
                
                % Store attributes if any
                if ~isempty(fieldnames(obj.attrs_store))
                    obj.store.set([obj.path '/.zattrs'], uint8(jsonencode(obj.attrs_store)));
                end
            end
        end
        
        function init_v3(obj)
            % Initialize group with v3 format
            if ~obj.store.contains([obj.path '/zarr.json'])
                % Create zarr.json metadata file
                metadata = struct();
                metadata.zarr_format = 3;
                metadata.node_type = 'group';
                metadata.attributes = obj.attrs_store;
                
                % Store metadata
                obj.store.set([obj.path '/zarr.json'], uint8(jsonencode(metadata)));
            end
        end
        
        function array = create_array(obj, name, shape, dtype, varargin)
            % Create a new array in this group
            %
            % Parameters:
            %   name: string
            %       Name of the array within this group
            %   shape: numeric vector
            %       Array shape
            %   dtype: string or numeric type
            %       Data type
            %   Additional parameters are passed to Array constructor
            
            % Validate inputs
            if ~ischar(name)
                error('zarr:InvalidName', 'Array name must be a string');
            end
            
            % Check if read-only
            if obj.read_only
                error('zarr:ReadOnlyError', 'Group is read-only');
            end
            
            % Check if name already exists
            if obj.contains(name)
                error('zarr:KeyError', 'Item with name ''%s'' already exists', name);
            end
            
            % Create array path
            array_path = fullfile(obj.path, name);
            
            % Create array
            array = zarr.core.Array(obj.store, array_path, shape, dtype, ...
                'zarr_format', obj.zarr_format, varargin{:});
        end
        
        function group = create_group(obj, name, varargin)
            % Create a new group under this group
            %
            % Parameters:
            %   name: string
            %       Name of the new group
            %   Additional parameters are passed to Group constructor
            
            % Validate inputs
            if ~ischar(name)
                error('zarr:InvalidName', 'Group name must be a string');
            end
            
            % Check if read-only
            if obj.read_only
                error('zarr:ReadOnlyError', 'Group is read-only');
            end
            
            % Check if name already exists
            if obj.contains(name)
                error('zarr:KeyError', 'Item with name ''%s'' already exists', name);
            end
            
            % Create group path
            group_path = fullfile(obj.path, name);
            
            % Create group
            group = zarr.core.Group(obj.store, group_path, ...
                'zarr_format', obj.zarr_format, varargin{:});
        end
        
        function tf = contains(obj, name)
            % Check if group contains an item with the given name
            %
            % Parameters:
            %   name: string
            %       Name to check
            %
            % Returns:
            %   tf: logical
            %       True if item exists
            
            % Build full path
            full_path = fullfile(obj.path, name);
            
            % Check if path exists in store
            tf = obj.store.contains([full_path '/zarr.json']) || ...
                 obj.store.contains([full_path '/.zarray']) || ...
                 obj.store.contains([full_path '/.zgroup']);
        end
        
        function items = list(obj)
            % List all items in this group
            %
            % Returns:
            %   items: struct array
            %       Array of structs with fields:
            %         name: string
            %           Item name
            %         type: string
            %           'array' or 'group'
            
            % List all keys in store under this path
            keys = obj.store.list(obj.path);
            
            % Process keys to find arrays and groups
            items = struct('name', {}, 'type', {});
            seen_paths = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            
            % First pass: collect all paths
            paths = {};
            for i = 1:numel(keys)
                [path, name] = fileparts(keys{i});
                if isempty(path) || strcmp(path, obj.path)
                    % Root-level item
                    if ~strcmp(name, '.zgroup') && ~strcmp(name, '.zattrs') && ~strcmp(name, 'attributes.json')
                        base_name = strrep(name, '.zarray', '');
                        base_name = strrep(base_name, 'zarr.json', '');
                        if ~isempty(base_name) && ~seen_paths.isKey(base_name)
                            paths{end+1} = base_name;
                            seen_paths(base_name) = true;
                        end
                    end
                else
                    % Nested item
                    rel_path = strrep(path, [obj.path '/'], '');
                    if ~isempty(rel_path) && ~seen_paths.isKey(rel_path)
                        parts = strsplit(rel_path, '/');
                        base_path = parts{1};
                        if ~seen_paths.isKey(base_path)
                            paths{end+1} = base_path;
                            seen_paths(base_path) = true;
                        end
                    end
                end
            end
            
            % Second pass: determine type for each path
            for i = 1:numel(paths)
                path = paths{i};
                full_path = fullfile(obj.path, path);
                
                if obj.store.contains([full_path '/zarr.json'])
                    % For v3, check node_type
                    json_bytes = obj.store.get([full_path '/zarr.json']);
                    metadata = jsondecode(char(json_bytes));
                    if isfield(metadata, 'node_type')
                        if strcmp(metadata.node_type, 'array')
                            items(end+1).name = path;
                            items(end).type = 'array';
                        elseif strcmp(metadata.node_type, 'group')
                            items(end+1).name = path;
                            items(end).type = 'group';
                        end
                    end
                elseif obj.store.contains([full_path '/.zarray'])
                    items(end+1).name = path;
                    items(end).type = 'array';
                elseif obj.store.contains([full_path '/.zgroup'])
                    items(end+1).name = path;
                    items(end).type = 'group';
                end
            end
            
            % Sort items by name to ensure consistent order
            if ~isempty(items)
                [~, idx] = sort({items.name});
                items = items(idx);
            end
        end
        
        function varargout = subsref(obj, s)
            % Implement array-like indexing for groups
            %
            % Example:
            %   group.array_name returns the array named 'array_name'
            %   group.subgroup.array_name navigates through hierarchy
            
            switch s(1).type
                case '.'
                    % Handle property access and method calls
                    if ismember(s(1).subs, properties(obj)) || ...
                       ismember(s(1).subs, methods(obj))
                        [varargout{1:nargout}] = builtin('subsref', obj, s);
                    else
                        % Try to get array or group
                        if obj.contains(s(1).subs)
                            item = obj.get_item(s(1).subs);
                            if length(s) > 1
                                [varargout{1:nargout}] = subsref(item, s(2:end));
                            else
                                varargout{1} = item;
                            end
                        else
                            error('zarr:KeyError', ...
                                'No item named ''%s'' in group', s(1).subs);
                        end
                    end
                otherwise
                    error('zarr:InvalidIndex', ...
                        'Invalid indexing type for group');
            end
        end
    end
    
    methods (Access = private)
        function item = get_item(obj, name)
            % Get array or group by name
            %
            % This is a helper method for subsref
            
            % Build full path
            full_path = fullfile(obj.path, name);
            
            % Check if it's a v3 item
            if obj.store.contains([full_path '/zarr.json'])
                json_bytes = obj.store.get([full_path '/zarr.json']);
                if isempty(json_bytes)
                    error('zarr:InvalidMetadata', 'Empty metadata file');
                end
                try
                    metadata = jsondecode(char(json_bytes));
                    if ~isfield(metadata, 'node_type')
                        error('zarr:InvalidMetadata', 'Missing node_type in metadata');
                    end
                    
                    if strcmp(metadata.node_type, 'array')
                        if ~isfield(metadata, 'shape')
                            error('zarr:InvalidMetadata', 'Missing shape in metadata');
                        end
                        shape = metadata.shape;
                        if isfield(metadata, 'data_type')
                            dtype = metadata.data_type;
                        elseif isfield(metadata, 'dtype')
                            dtype = metadata.dtype;
                        else
                            error('zarr:InvalidMetadata', 'Missing data type in metadata');
                        end
                        item = zarr.core.Array(obj.store, full_path, shape, dtype, ...
                            'zarr_format', obj.zarr_format);
                    elseif strcmp(metadata.node_type, 'group')
                        item = zarr.core.Group(obj.store, full_path, ...
                            'zarr_format', obj.zarr_format);
                    else
                        error('zarr:InvalidMetadata', 'Invalid node_type: %s', metadata.node_type);
                    end
                catch ME
                    error('zarr:InvalidMetadata', 'Failed to parse metadata: %s\nContent: %s', ...
                        ME.message, char(json_bytes));
                end
            % Check if it's a v2 array
            elseif obj.store.contains([full_path '/.zarray'])
                json_bytes = obj.store.get([full_path '/.zarray']);
                if isempty(json_bytes)
                    error('zarr:InvalidMetadata', 'Empty metadata file');
                end
                try
                    metadata = jsondecode(char(json_bytes));
                    if ~isfield(metadata, 'shape')
                        error('zarr:InvalidMetadata', 'Missing shape in metadata');
                    end
                    shape = metadata.shape;
                    if isfield(metadata, 'dtype')
                        dtype = metadata.dtype;
                    else
                        error('zarr:InvalidMetadata', 'Missing data type in metadata');
                    end
                    item = zarr.core.Array(obj.store, full_path, shape, dtype, ...
                        'zarr_format', obj.zarr_format);
                catch ME
                    error('zarr:InvalidMetadata', 'Failed to parse metadata: %s\nContent: %s', ...
                        ME.message, char(json_bytes));
                end
            % Check if it's a v2 group
            elseif obj.store.contains([full_path '/.zgroup'])
                item = zarr.core.Group(obj.store, full_path, ...
                    'zarr_format', obj.zarr_format);
            else
                error('zarr:KeyError', ...
                    'No item named ''%s'' in group', name);
            end
        end
    end
