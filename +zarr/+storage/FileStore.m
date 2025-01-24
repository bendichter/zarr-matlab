classdef FileStore < zarr.core.Store
    % FILESTORE Store implementation using local filesystem
    %   Provides storage backend using local filesystem for Zarr arrays.
    %   Each chunk and metadata file is stored as a separate file.
    
    properties (Access = private)
        root        % Root directory path
        read_only   % Whether store is read-only
        normalize   % Whether to normalize path separators
    end
    
    methods (Access = public)
        function tf = isreadonly(obj)
            % Check if store is read-only
            tf = obj.read_only;
        end
        
        function tf = supports_deletes(obj)
            % Check if store supports delete operations
            tf = true;
        end
        
        function tf = eq(obj1, obj2)
            % Equality comparison
            if ~isa(obj2, 'zarr.storage.FileStore')
                tf = false;
                return;
            end
            % Stores are only equal if they have the same root path and settings
            tf = strcmp(obj1.root, obj2.root) && ...
                 obj1.read_only == obj2.read_only && ...
                 obj1.normalize == obj2.normalize;
        end
        
        function tf = ne(obj1, obj2)
            % Not equal comparison
            tf = ~eq(obj1, obj2);
        end
    end
    
    methods
        function obj = FileStore(path, varargin)
            % Create a new FileStore
            %
            % Parameters:
            %   path: string
            %       Path to root directory
            %   Optional parameters (name-value pairs):
            %     'read_only': logical
            %         Whether store is read-only (default: false)
            %     'normalize': logical
            %         Whether to normalize path separators (default: true)
            
            % Parse inputs
            p = inputParser;
            p.addRequired('path', @(x) ischar(x) || isstring(x));
            if numel(varargin) == 1 && islogical(varargin{1})
                % Support legacy constructor with normalize parameter
                normalize = varargin{1};
                read_only = false;
            else
                p.addParameter('read_only', false, @islogical);
                p.addParameter('normalize', true, @islogical);  % Changed default to true
                p.parse(path, varargin{:});
                read_only = p.Results.read_only;
                normalize = p.Results.normalize;
            end
            
            % Store properties
            obj.root = char(path);
            obj.read_only = read_only;
            obj.normalize = normalize;
            
            % Create directory if it doesn't exist
            if ~exist(obj.root, 'dir')
                if obj.read_only
                    error('zarr:ReadOnlyError', ...
                        'Cannot create directory in read-only mode');
                end
                [success, msg] = mkdir(obj.root);
                if ~success
                    error('zarr:StoreError', ...
                        'Failed to create directory: %s', msg);
                end
            end
        end
        
        function tf = contains(obj, key)
            % Check if key exists in store
            %
            % Parameters:
            %   key: string
            %       Store key
            %
            % Returns:
            %   tf: logical
            %       True if key exists
            
            mustBeNonzeroLengthText(key);
            
            % Normalize key if enabled
            if obj.normalize
                key = strrep(key, '\', '/');
            end
            
            % Get full path
            path = fullfile(obj.root, key);
            
            % Check if file exists
            tf = exist(path, 'file') == 2;
        end
        
        function data = get(obj, key)
            % Get data for key
            %
            % Parameters:
            %   key: string
            %       Store key
            %
            % Returns:
            %   data: uint8 vector
            %       Data as bytes
            
            mustBeNonzeroLengthText(key);
            
            % Normalize key if enabled
            if obj.normalize
                key = strrep(key, '\', '/');
            end
            
            % Get full path
            path = fullfile(obj.root, key);
            
            % Check if file exists
            if ~exist(path, 'file')
                data = uint8([]);
                return;
            end
            
            try
                % Read file
                fid = fopen(path, 'rb');
                if fid == -1
                    error('zarr:StoreError', ...
                        'Failed to open file: %s', path);
                end
                cleanup = onCleanup(@() fclose(fid));
                
                % Read all bytes
                data = fread(fid, Inf, 'uint8=>uint8')';
            catch ME
                error('zarr:StoreError', ...
                    'Failed to read file: %s (%s)', path, ME.message);
            end
        end
        
        function set(obj, key, value)
            % Set data for key
            %
            % Parameters:
            %   key: string
            %       Store key
            %   value: uint8 vector
            %       Data as bytes
            
            mustBeNonzeroLengthText(key);
            
            % Check if read-only
            if obj.read_only
                error('zarr:ReadOnlyError', ...
                    'Store is read-only');
            end
            
            % Normalize key if enabled
            if obj.normalize
                key = strrep(key, '\', '/');
            end
            
            % Get full path
            path = fullfile(obj.root, key);
            
            % Create directory if needed
            dir_path = fileparts(path);
            if ~exist(dir_path, 'dir')
                [success, msg] = mkdir(dir_path);
                if ~success
                    error('zarr:StoreError', ...
                        'Failed to create directory: %s', msg);
                end
            end
            
            try
                % Write file
                fid = fopen(path, 'wb');
                if fid == -1
                    error('zarr:StoreError', ...
                        'Failed to open file: %s', path);
                end
                cleanup = onCleanup(@() fclose(fid));
                
                % Write bytes
                fwrite(fid, value, 'uint8');
            catch ME
                error('zarr:StoreError', ...
                    'Failed to write file: %s (%s)', path, ME.message);
            end
        end
        
        function delete(obj, key)
            % Delete key from store
            %
            % Parameters:
            %   key: string
            %       Store key
            
            mustBeNonzeroLengthText(key);
            
            % Check if read-only
            if obj.read_only
                error('zarr:ReadOnlyError', ...
                    'Store is read-only');
            end
            
            % Normalize key if enabled
            if obj.normalize
                key = strrep(key, '\', '/');
            end
            
            % Get full path
            path = fullfile(obj.root, key);
            
            % Delete file if it exists
            if exist(path, 'file')
                try
                    delete(path);
                catch ME
                    error('zarr:StoreError', ...
                        'Failed to delete file: %s (%s)', path, ME.message);
                end
            end
        end
        
        function keys = list(obj, prefix)
            % List all keys in store
            %
            % Parameters:
            %   prefix: string (optional)
            %       Only list keys starting with prefix
            %
            % Returns:
            %   keys: cell array
            %       List of store keys
            
            if nargin < 2
                prefix = '';
            end
            
            % Normalize prefix if enabled
            if obj.normalize
                prefix = strrep(prefix, '\', '/');
            end
            
            % Get all files recursively
            search_path = fullfile(obj.root, prefix, '**', '*');
            files = dir(search_path);
            
            % Filter out directories
            files = files(~[files.isdir]);
            
            % Convert to relative paths
            keys = cell(numel(files), 1);
            root_len = length(obj.root) + 1;
            for i = 1:numel(files)
                % Get path relative to root
                full_path = fullfile(files(i).folder, files(i).name);
                rel_path = full_path(root_len:end);
                
                % Remove leading separator if present
                if startsWith(rel_path, '/') || startsWith(rel_path, '\')
                    rel_path = rel_path(2:end);
                end
                
                % Normalize path separators if enabled
                if obj.normalize
                    rel_path = strrep(rel_path, '\', '/');
                end
                
                keys{i} = rel_path;
            end
        end
        
        function rmdir(obj, path)
            % Remove directory and all contents
            %
            % Parameters:
            %   path: string (optional)
            %       Path to remove (relative to root). If not provided,
            %       removes entire store directory.
            
            % Check if read-only
            if obj.read_only
                error('zarr:ReadOnlyError', ...
                    'Store is read-only');
            end
            
            % Default to root if no path provided
            if nargin < 2
                path = '';
            end
            
            % Normalize path if enabled
            if obj.normalize
                path = strrep(path, '\', '/');
            end
            
            % Get full path
            full_path = fullfile(obj.root, path);
            
            % Remove directory if it exists
            if exist(full_path, 'dir')
                [success, msg] = rmdir(full_path, 's');
                if ~success
                    error('zarr:StoreError', ...
                        'Failed to remove directory: %s', msg);
                end
            end
        end
    end
end
