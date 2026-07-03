function full = resolve_relative(base, rel)
%RESOLVE_RELATIVE Resolve rel against a base directory (path or URL),
%   normalizing "." and ".." segments. Absolute rel (URL or filesystem
%   path) is returned as-is.

base = string(base);
rel = string(rel);
if startsWith(rel, "http://") || startsWith(rel, "https://")
    full = rel;
    return
end

isHttp = startsWith(base, "http://") || startsWith(base, "https://");
if ~isHttp && (startsWith(rel, "/") || ~isempty(regexp(rel, '^[A-Za-z]:[\\/]', 'once')))
    full = rel;  % absolute filesystem path
    return
end

if isHttp
    tok = regexp(char(base), '^(https?://[^/]+)(.*)$', 'tokens', 'once');
    hostPart = string(tok{1});
    pathPart = string(tok{2});
    segs = split(pathPart, "/");
else
    hostPart = "";
    segs = split(strrep(base, "\", "/"), "/");
end
segs = segs(strlength(segs) > 0);
leadingSlash = ~isHttp && startsWith(strrep(base, "\", "/"), "/");

for s = reshape(split(strrep(rel, "\", "/"), "/"), 1, [])
    if s == "" || s == "."
        continue
    elseif s == ".."
        if isempty(segs)
            error("zarr:StoreError", "Relative path '%s' escapes above the root.", rel);
        end
        segs(end) = [];
    else
        segs(end + 1, 1) = s; %#ok<AGROW>
    end
end

joined = strjoin(segs, "/");
if isHttp
    full = hostPart + "/" + joined;
elseif leadingSlash
    full = "/" + joined;
else
    full = joined;
end
end
