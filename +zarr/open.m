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
%     'zarr_format': numeric
%         Zarr format version (2 or 3, default: 3)
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
%     % Open a group with specific format version
%     group = zarr.open(store, 'path', 'group1', 'zarr_format', 2);

    % Parse input arguments
    p = inputParser;
    p.addRequired('store', @(x) isa(x, 'zarr.core.Store'));
    p.addParameter('path', '', @ischar);
    p.addParameter('zarr_format', 3, @(x) ismember(x, [2, 3]));
    p.addParameter('mode', 'r+', @(x) ismember(x, {'r', 'r+'}));
    
    p.parse(store, varargin{:});
    
    % Extract parameters
    path = p.Results.path;
    zarr_format = p.Results.zarr_format;
    mode = p.Results.mode;
    
    % Check if path exists
    if ~store.contains([path '/zarr.json']) && ...
       ~store.contains([path '/.zarray']) && ...
       ~store.contains([path '/.zgroup'])
        error('zarr:PathNotFound', ...
            'No array or group found at path: %s', path);
    end
    
    % Determine if path points to array or group
    if store.contains([path '/zarr.json']) || ...
       store.contains([path '/.zarray'])
        % Path points to array
        obj = zarr.core.Array(store, path, ...
            'zarr_format', zarr_format);
    else
        % Path points to group
        obj = zarr.core.Group(store, path, ...
            'zarr_format', zarr_format);
    end
    
    % Set read-only mode if requested
    if strcmp(mode, 'r')
        if ~isa(store, 'zarr.storage.FileStore')
            error('zarr:UnsupportedOperation', ...
                'Read-only mode only supported for FileStore');
        end
        store.read_only = true;
    end
end
