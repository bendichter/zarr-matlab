function group = group(varargin)
% GROUP Create a new Zarr group
%   GROUP = GROUP() creates a new Zarr group with default settings in a
%   temporary store.
%
%   GROUP = GROUP(STORE) creates a new Zarr group in the specified store.
%
%   GROUP = GROUP(..., 'Name', Value) specifies additional parameters using
%   name-value pairs:
%
%   Parameters:
%     'path': string
%         Path within store (default: '')
%     'zarr_format': numeric
%         Zarr format version (2 or 3, default: 3)
%     'attributes': struct
%         User-defined attributes
%
%   Examples:
%     % Create a group with default settings
%     g = zarr.group();
%
%     % Create a group in a specific store
%     store = zarr.storage.FileStore('data.zarr');
%     g = zarr.group(store);
%
%     % Create a group with attributes
%     g = zarr.group('attributes', struct('description', 'My group'));
%
%     % Create a nested group
%     g = zarr.group(store, 'path', 'subgroup');

    % Parse input arguments
    [store, params] = parse_args(varargin{:});
    
    % Create group
    group = zarr.core.Group(store, params.path, ...
        'zarr_format', params.zarr_format, ...
        'attributes', params.attributes);
end

function [store, params] = parse_args(varargin)
    % Handle different call signatures
    if isempty(varargin)
        % group()
        store = zarr.storage.FileStore(tempname);
        args = {};
    elseif isa(varargin{1}, 'zarr.core.Store')
        % group(store, ...)
        store = varargin{1};
        args = varargin(2:end);
    else
        % group('Name', Value, ...)
        store = zarr.storage.FileStore(tempname);
        args = varargin;
    end
    
    % Set default parameters
    params = struct();
    params.path = '';
    params.zarr_format = 3;
    params.attributes = struct();
    
    % Parse optional parameters
    if ~isempty(args)
        if mod(numel(args), 2) ~= 0
            error('zarr:InvalidArguments', ...
                'Optional parameters must be specified as name-value pairs');
        end
        
        for i = 1:2:numel(args)
            name = args{i};
            value = args{i+1};
            
            switch lower(name)
                case 'path'
                    params.path = value;
                case 'zarr_format'
                    params.zarr_format = value;
                case 'attributes'
                    params.attributes = value;
                otherwise
                    error('zarr:InvalidParameter', ...
                        'Unknown parameter: %s', name);
            end
        end
    end
end
