function store = resolve_store(store)
%RESOLVE_STORE Accept a Store object or a filesystem path string.

if isa(store, 'zarr.stores.Store')
    return
elseif ischar(store) || isstring(store)
    store = zarr.stores.LocalStore(string(store));
else
    error("zarr:InvalidStore", ...
        "Expected a zarr.stores.Store or a directory path, got %s.", class(store));
end
end
