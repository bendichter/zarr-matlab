classdef DirectoryStore < zarr.core.Store
    %DIRECTORYSTORE Store class that uses directories for storage
    
    properties
        root  % Root directory path
        normalize  % Whether to normalize file paths
    end
    
    methods
        function obj = DirectoryStore(path, normalize)
            %DIRECTORYSTORE Construct directory store
            %   store = DirectoryStore(path) creates a store using the specified
            %   directory path for storage
            %   store = DirectoryStore(path, normalize) optionally specifies
            %   whether to normalize file paths (default true)
            
            if nargin < 2
                normalize = true;
            end
            
            % Ensure path exists
            if ~exist(path, 'dir')
                mkdir(path);
            end
            
            obj.root = path;
            obj.normalize = normalize;
        end
        
        function tf = isreadonly(obj)
            tf = false;
        end
        
        function tf = supports_deletes(obj)
            tf = true;
        end
        
        function set(obj, key, value)
            arguments
                obj
                key (1,1) string {mustBeNonzeroLengthText}
                value
            end
            
            % Get normalized path
            filepath = obj.get_path(key);
            
            % Ensure directory exists
            [dirpath, ~, ~] = fileparts(filepath);
            if ~exist(dirpath, 'dir')
                mkdir(dirpath);
            end
            
            % Write data
            fid = fopen(filepath, 'wb');
            if fid == -1
                error('Failed to open file for writing: %s', filepath);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, value, 'uint8');
        end
        
        function data = get(obj, key)
            % Get data for key, or empty if not found
            filepath = obj.get_path(key);
            if ~exist(filepath, 'file')
                data = [];
                return;
            end
            
            % Read data
            fid = fopen(filepath, 'rb');
            if fid == -1
                error('Failed to open file for reading: %s', filepath);
            end
            cleanup = onCleanup(@() fclose(fid));
            data = fread(fid, Inf, 'uint8=>uint8')';
        end
        
        function delete(obj, key)
            % Delete data for key if it exists
            filepath = obj.get_path(key);
            if exist(filepath, 'file')
                delete(filepath);
                
                % Try to clean up empty parent directories
                try
                    [parent, ~, ~] = fileparts(filepath);
                    while ~isempty(parent) && strcmp(parent, obj.root) == 0
                        if isempty(dir(fullfile(parent, '*')))
                            rmdir(parent);
                            [parent, ~, ~] = fileparts(parent);
                        else
                            break;
                        end
                    end
                catch
                    % Ignore cleanup errors
                end
            end
        end
        
        function tf = contains(obj, key)
            % Check if key exists
            filepath = obj.get_path(key);
            tf = exist(filepath, 'file') == 2;
        end
        
        function keys = list(obj, prefix)
            % List all keys with optional prefix
            if nargin < 2
                prefix = '';
            end
            
            % Get all files recursively
            files = dir(fullfile(obj.root, '**', '*'));
            files = files(~[files.isdir]);  % Exclude directories
            
            % Convert to keys
            keys = {};
            prefix_path = obj.get_path(prefix);
            for i = 1:numel(files)
                filepath = fullfile(files(i).folder, files(i).name);
                if startsWith(filepath, prefix_path)
                    % Convert file path to key
                    key = strrep(filepath, [obj.root filesep], '');
                    if obj.normalize
                        key = strrep(key, '\', '/');
                    end
                    keys{end+1} = key;
                end
            end
        end
        
        function rmdir(obj, path)
            % Remove directory and contents
            dirpath = fullfile(obj.root, path);
            if exist(dirpath, 'dir')
                rmdir(dirpath, 's');
            end
        end
        
        function tf = eq(obj, other)
            % Test equality with another store
            if ~isa(other, 'zarr.storage.DirectoryStore')
                tf = false;
                return;
            end
            tf = strcmp(obj.root, other.root) && ...
                 obj.normalize == other.normalize;
        end
    end
    
    methods (Access = private)
        function path = get_path(obj, key)
            % Get full filesystem path for key
            if obj.normalize
                key = strrep(key, '\', '/');
            end
            path = fullfile(obj.root, key);
        end
    end
end
