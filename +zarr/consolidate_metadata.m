function consolidate_metadata(store)
%CONSOLIDATE_METADATA Inline all node metadata into the root group's
%   zarr.json (consolidated_metadata), so hierarchies can be opened with a
%   single read. Matches zarr-python's v3 consolidated format.

store = zarr.internal.resolve_store(store);

[rootBytes, found] = store.get("zarr.json");
if ~found
    error("zarr:NodeNotFound", "No root node to consolidate.");
end
rootTxt = native2unicode(rootBytes, 'UTF-8');
rootMeta = zarr.metadata.GroupMetadata.fromJsonText(rootTxt);  % errors on arrays

map = containers.Map('KeyType', 'char', 'ValueType', 'any');
ks = store.list();
for i = 1:numel(ks)
    k = ks(i);
    if ~endsWith(k, "/zarr.json")
        continue
    end
    path = extractBefore(k, strlength(k) - strlength("/zarr.json") + 1);
    [bytes, ~] = store.get(k);
    map(char(path)) = string(native2unicode(bytes, 'UTF-8'));
end

rootMeta.consolidated = map;
store.set("zarr.json", unicode2native(char(rootMeta.toJsonText()), 'UTF-8'));
end
