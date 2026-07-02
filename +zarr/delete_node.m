function delete_node(store, path)
%DELETE_NODE Remove an array or group (recursively) from a store.
%   zarr.delete_node(store, "group/array") removes the node's metadata and
%   all data under it. Deleting the root path ("") empties the store.

store = zarr.internal.resolve_store(store);
path = zarr.internal.normalize_path(path);

if strlength(path) == 0
    metaKey = "zarr.json";
    prefix = "";
else
    metaKey = path + "/zarr.json";
    prefix = path + "/";
end
if ~store.exists(metaKey)
    error("zarr:NodeNotFound", "No node exists at '%s'.", path);
end

ks = store.list();
for i = 1:numel(ks)
    if ks(i) == metaKey || (strlength(prefix) > 0 && startsWith(ks(i), prefix)) ...
            || (strlength(prefix) == 0 && ks(i) ~= "zarr.json")
        store.erase(ks(i));
    end
end
store.erase(metaKey);
end
