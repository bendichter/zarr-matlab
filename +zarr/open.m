function obj = open(store, varargin)
% OPEN Open an existing Zarr array or group
%   OBJ = OPEN(STORE) opens the root group or array in the specified store.
%
%   OBJ = OPEN(STORE, 'Name', Value) specifies additional parameters using
%   name-value pairs:
%
%   Parameters:
%     'path': string
%         Path within store (default: '')
%     'mode': char
%         Storage mode ('r' or 'r+', default: 'r+')
%
%   Returns:
%     obj: zarr.core.Array or zarr.core.Group
%         The opened array or group
%
%   Examples:
%     % Open root group from a store
%     store = zarr.storage.FileStore('data.zarr');
%     root = zarr.open(store);
%
%     % Open a specific array with read-only access
%     array = zarr.open(store, 'path', 'data/array1', 'mode', 'r');
%
%     % Open a group
%     group = zarr.open(store, 'path', 'group1');

    % Parse input arguments
    p = inputParser;
    p.addRequired('store', @(x) isa(x, 'zarr.core.Store'));
    p.addParameter('path', '', @ischar);
    p.addParameter('mode', 'r+', @check_mode);
    
    p.parse(store, varargin{:});
    
    % Extract parameters
    path = p.Results.path;
    mode = p.Results.mode;
    
    % Create read-only store if requested
    if strcmp(mode, 'r')
        if ~isa(store, 'zarr.storage.FileStore')
            error('MATLAB:InputParser:ArgumentValue', ...
                'Read-only mode only supported for FileStore');
        end
        % Create new store with read_only flag
        store = zarr.storage.FileStore(store.root, 'read_only', true, 'normalize', store.normalize);
    end
    
    % Check if path exists
    if ~store.contains([path '/.zarray']) && ...
       ~store.contains([path '/.zgroup'])
        error('zarr:PathNotFound', ...
            'No array or group found at path: %s', path);
    end
    
    % Determine if path points to array or group
    if store.contains([path '/.zarray'])
        % Path points to array
        obj = zarr.core.Array.from_metadata(store, path);
    else
        % Path points to group
        obj = zarr.core.Group(store, path);
    end
end

function tf = check_mode(x)
    % Validate mode parameter
    if ~ischar(x)
        error('MATLAB:InputParser:ArgumentValue', ...
            'Mode must be a character array');
    end
    if ~ismember(x, {'r', 'r+'})
        error('MATLAB:InputParser:ArgumentValue', ...
            'Mode must be ''r'' or ''r+''');
    end
    tf = true;
end
