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
    
    methods
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
            
            % Input validation
            p = inputParser;
            p.addRequired('store', @(x) isa(x, 'zarr.core.Store'));
            p.addRequired('path', @ischar);
            p.addParameter('zarr_format', 3, @(x) ismember(x, [2, 3]));
            
            p.parse(store, path, varargin{:});
            
            % Store properties
            obj.store = p.Results.store;
            obj.path = p.Results.path;
            obj.zarr_format = p.Results.zarr_format;
            obj.read_only = obj.store.isreadonly();
            
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
            % Implementation will go here
            error('zarr:NotImplemented', 'v2 format initialization not yet implemented');
        end
        
        function init_v3(obj)
            % Initialize group with v3 format
            % Implementation will go here
            error('zarr:NotImplemented', 'v3 format initialization not yet implemented');
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
            for i = 1:numel(keys)
                [path, name] = fileparts(keys{i});
                if strcmp(name, 'zarr.json') || strcmp(name, '.zarray')
                    items(end+1).name = path;
                    items(end).type = 'array';
                elseif strcmp(name, '.zgroup')
                    items(end+1).name = path;
                    items(end).type = 'group';
                end
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
            
            % Check if it's an array
            if obj.store.contains([full_path '/zarr.json']) || ...
               obj.store.contains([full_path '/.zarray'])
                item = zarr.core.Array(obj.store, full_path, ...
                    'zarr_format', obj.zarr_format);
            % Check if it's a group
            elseif obj.store.contains([full_path '/.zgroup'])
                item = zarr.core.Group(obj.store, full_path, ...
                    'zarr_format', obj.zarr_format);
            else
                error('zarr:KeyError', ...
                    'No item named ''%s'' in group', name);
            end
        end
    end
end
