classdef MemoryStore < zarr.stores.Store
    %MEMORYSTORE In-memory key/value store, mainly for testing and scratch use.

    properties (Access = private)
        map
    end

    methods
        function obj = MemoryStore()
            obj.map = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function [data, found] = get(obj, key)
            key = char(key);
            found = obj.map.isKey(key);
            if found
                data = obj.map(key);
            else
                data = uint8([]);
            end
        end

        function tf = exists(obj, key)
            tf = obj.map.isKey(char(key));
        end

        function set(obj, key, data)
            obj.map(char(key)) = uint8(data(:)');
        end

        function erase(obj, key)
            key = char(key);
            if obj.map.isKey(key)
                obj.map.remove(key);
            end
        end

        function ks = list(obj)
            ks = string(obj.map.keys())';
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
            files = rel(~hasSlash);
            subdirs = unique(extractBefore(rel(hasSlash), "/"));
        end
    end
end
