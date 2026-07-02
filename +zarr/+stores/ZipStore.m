classdef ZipStore < zarr.stores.Store
    %ZIPSTORE Zarr store backed by a single .zip file.
    %   zarr.stores.ZipStore(path)             open existing zip, read-only
    %   zarr.stores.ZipStore(path, Mode="w")   create a new zip for writing;
    %                                          entries accumulate in memory and
    %                                          the file is written by close()
    %                                          (also called by the destructor).
    %
    %   Matches zarr-python's ZipStore layout: node paths as plain entry names.

    properties (SetAccess = immutable)
        path (1,1) string
        mode (1,1) string
    end

    properties (Access = private)
        zf              % java.util.zip.ZipFile (read mode)
        pending         % containers.Map (write mode)
        isClosed (1,1) logical = false
    end

    methods
        function obj = ZipStore(path, opts)
            arguments
                path (1,1) string
                opts.Mode (1,1) string {mustBeMember(opts.Mode, ["r", "w"])} = "r"
            end
            obj.path = path;
            obj.mode = opts.Mode;
            if obj.mode == "r"
                if ~isfile(path)
                    error("zarr:StoreError", "Zip file '%s' does not exist.", path);
                end
                obj.zf = java.util.zip.ZipFile(java.io.File(char(path)));
            else
                obj.pending = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
        end

        function [data, found] = get(obj, key)
            obj.assertOpen();
            if obj.mode == "w"
                found = obj.pending.isKey(char(key));
                if found
                    data = obj.pending(char(key));
                else
                    data = uint8([]);
                end
                return
            end
            entry = obj.zf.getEntry(char(key));
            if isempty(entry)
                data = uint8([]);
                found = false;
                return
            end
            is = obj.zf.getInputStream(entry);
            data = typecast(int8(org.apache.commons.io.IOUtils.toByteArray(is))', 'uint8');
            is.close();
            found = true;
        end

        function tf = exists(obj, key)
            obj.assertOpen();
            if obj.mode == "w"
                tf = obj.pending.isKey(char(key));
            else
                tf = ~isempty(obj.zf.getEntry(char(key)));
            end
        end

        function set(obj, key, data)
            obj.assertWritable();
            obj.pending(char(key)) = uint8(data(:)');
        end

        function erase(obj, key)
            obj.assertWritable();
            if obj.pending.isKey(char(key))
                obj.pending.remove(char(key));
            end
        end

        function ks = list(obj)
            obj.assertOpen();
            if obj.mode == "w"
                ks = string(obj.pending.keys())';
                return
            end
            e = obj.zf.entries();
            ks = strings(0, 1);
            while e.hasMoreElements()
                entry = e.nextElement();
                name = string(entry.getName());
                if ~entry.isDirectory()
                    ks(end + 1, 1) = name; %#ok<AGROW>
                end
            end
            ks = sort(ks);
        end

        function [subdirs, files] = listDir(obj, prefix)
            prefix = string(prefix);
            if strlength(prefix) > 0
                pre = prefix + "/";
            else
                pre = "";
            end
            ks = obj.list();
            rel = ks(startsWith(ks, pre));
            rel = extractAfter(rel, strlength(pre));
            hasSlash = contains(rel, "/");
            files = rel(~hasSlash & strlength(rel) > 0);
            subdirs = unique(extractBefore(rel(hasSlash), "/"));
        end

        function close(obj)
            if obj.isClosed
                return
            end
            obj.isClosed = true;
            if obj.mode == "r"
                obj.zf.close();
                return
            end
            % Write all pending entries in one pass (deflate-compressed).
            fos = java.io.FileOutputStream(char(obj.path));
            zos = java.util.zip.ZipOutputStream(fos);
            keys = sort(string(obj.pending.keys())');
            for i = 1:numel(keys)
                zos.putNextEntry(java.util.zip.ZipEntry(char(keys(i))));
                data = obj.pending(char(keys(i)));
                if ~isempty(data)
                    zos.write(typecast(uint8(data), 'int8'));
                end
                zos.closeEntry();
            end
            zos.close();
        end

        function delete(obj)
            try %#ok<TRYNC> destructor must not throw
                obj.close();
            end
        end
    end

    methods (Access = private)
        function assertOpen(obj)
            if obj.isClosed
                error("zarr:StoreError", "ZipStore '%s' is closed.", obj.path);
            end
        end

        function assertWritable(obj)
            obj.assertOpen();
            if obj.mode ~= "w"
                error("zarr:StoreError", ...
                    "ZipStore '%s' is read-only; open with Mode=""w"" to write.", obj.path);
            end
        end
    end
end
