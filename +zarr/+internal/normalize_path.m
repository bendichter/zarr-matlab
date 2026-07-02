function p = normalize_path(p)
%NORMALIZE_PATH Normalize a node path: no leading/trailing/duplicate slashes.

p = string(p);
parts = split(p, "/");
parts = parts(strlength(parts) > 0);
if any(parts == "." | parts == "..")
    error("zarr:InvalidPath", "Node paths may not contain '.' or '..' segments.");
end
p = strjoin(parts, "/");
end
