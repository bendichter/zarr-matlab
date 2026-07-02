function ensure_parents(store, path)
%ENSURE_PARENTS Create group metadata for all ancestors of path (incl. root).

path = zarr.internal.normalize_path(path);
if strlength(path) == 0
    ancestors = string.empty;
else
    parts = split(path, "/");
    ancestors = strings(1, numel(parts));  % "", "a", "a/b", ... (excl. path itself)
    ancestors(1) = "";
    for i = 2:numel(parts)
        ancestors(i) = strjoin(parts(1:i - 1), "/");
    end
end

gm = zarr.metadata.GroupMetadata();
for a = ancestors
    if strlength(a) == 0
        key = "zarr.json";
    else
        key = a + "/zarr.json";
    end
    [bytes, found] = store.get(key);
    if found
        m = jsondecode(native2unicode(bytes, 'UTF-8'));
        if ~strcmp(m.node_type, 'group')
            error("zarr:NodeExists", ...
                "Cannot create node under '%s': an array already exists there.", a);
        end
    else
        store.set(key, unicode2native(char(gm.toJsonText()), 'UTF-8'));
    end
end
end
