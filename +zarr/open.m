function node = open(store, opts)
%OPEN Open an existing Zarr v3 array or group.
%   node = zarr.open(store) opens the root node. store is a directory path
%   or a zarr.stores.Store. Use Path to open a node inside the hierarchy:
%   node = zarr.open("data.zarr", Path="group/array")

arguments
    store
    opts.Path (1,1) string = ""
end

store = zarr.internal.resolve_store(store);
path = zarr.internal.normalize_path(opts.Path);
if strlength(path) == 0
    key = "zarr.json";
else
    key = path + "/zarr.json";
end

[bytes, found] = store.get(key);
if ~found
    error("zarr:NodeNotFound", "No Zarr v3 node found at '%s' (missing %s).", path, key);
end
txt = native2unicode(bytes, 'UTF-8');
m = jsondecode(txt);
if ~isfield(m, 'node_type')
    error("zarr:InvalidMetadata", "zarr.json at '%s' has no node_type.", path);
end

switch string(m.node_type)
    case "array"
        node = zarr.Array(store, path, zarr.metadata.ArrayMetadata.fromJsonText(txt));
    case "group"
        node = zarr.Group(store, path, zarr.metadata.GroupMetadata.fromJsonText(txt));
    otherwise
        error("zarr:InvalidMetadata", "Unknown node_type '%s'.", m.node_type);
end
end
