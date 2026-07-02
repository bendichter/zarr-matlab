classdef LocalStore < zarr.stores.Store
    %LOCALSTORE Key/value store over a local directory.

    properties (SetAccess = immutable)
        root (1,1) string
    end

    methods
        function obj = LocalStore(root)
            obj.root = string(root);
        end

        function [data, found] = get(obj, key)
            fid = fopen(obj.keyPath(key), 'r');
            if fid == -1
                data = uint8([]);
                found = false;
                return
            end
            cleaner = onCleanup(@() fclose(fid));
            data = fread(fid, Inf, '*uint8')';
            found = true;
        end

        function [data, found] = getPartial(obj, key, offset, len)
            fid = fopen(obj.keyPath(key), 'r');
            if fid == -1
                data = uint8([]);
                found = false;
                return
            end
            cleaner = onCleanup(@() fclose(fid));
            fseek(fid, offset, 'bof');
            data = fread(fid, len, '*uint8')';
            found = true;
        end

        function [data, found] = getSuffix(obj, key, len)
            fid = fopen(obj.keyPath(key), 'r');
            if fid == -1
                data = uint8([]);
                found = false;
                return
            end
            cleaner = onCleanup(@() fclose(fid));
            fseek(fid, 0, 'eof');
            n = ftell(fid);
            fseek(fid, max(0, n - len), 'bof');
            data = fread(fid, len, '*uint8')';
            found = true;
        end

        function tf = exists(obj, key)
            tf = isfile(obj.keyPath(key));
        end

        function set(obj, key, data)
            p = obj.keyPath(key);
            d = fileparts(p);
            if strlength(string(d)) > 0 && ~isfolder(d)
                mkdir(d);
            end
            % Write to a temp file in the same directory, then move into
            % place so concurrent readers never see partial chunks.
            [~, tmpName] = fileparts(tempname);
            tmp = p + "." + tmpName + ".partial";
            fid = fopen(tmp, 'w');
            if fid == -1
                error("zarr:StoreError", "Cannot write to '%s'.", p);
            end
            fwrite(fid, uint8(data(:)'), 'uint8');
            fclose(fid);
            movefile(tmp, p, 'f');
        end

        function erase(obj, key)
            p = obj.keyPath(key);
            if isfile(p)
                delete(p);
            end
        end

        function ks = list(obj)
            if ~isfolder(obj.root)
                ks = string.empty(0, 1);
                return
            end
            entries = dir(fullfile(obj.root, '**', '*'));
            entries = entries(~[entries.isdir]);
            n = numel(entries);
            ks = strings(n, 1);
            rootAbs = string(obj.absRoot());
            for i = 1:n
                full = string(fullfile(entries(i).folder, entries(i).name));
                rel = extractAfter(full, strlength(rootAbs));
                rel = strip(rel, 'left', filesep);
                ks(i) = strjoin(split(rel, filesep), "/");
            end
            ks = sort(ks);
        end

        function [subdirs, files] = listDir(obj, prefix)
            prefix = string(prefix);
            if strlength(prefix) > 0
                d = fullfile(obj.root, strjoin(split(prefix, "/"), filesep));
            else
                d = obj.root;
            end
            subdirs = string.empty(0, 1);
            files = string.empty(0, 1);
            if ~isfolder(d)
                return
            end
            entries = dir(d);
            entries = entries(~ismember({entries.name}, {'.', '..'}));
            names = string({entries.name})';
            isd = [entries.isdir]';
            subdirs = names(isd);
            files = names(~isd);
        end
    end

    methods (Access = private)
        function p = keyPath(obj, key)
            p = string(fullfile(obj.root, strjoin(split(string(key), "/"), filesep)));
        end

        function r = absRoot(obj)
            d = dir(obj.root);
            if isempty(d)
                r = obj.root;
            else
                r = string(d(1).folder);
            end
        end
    end
end
