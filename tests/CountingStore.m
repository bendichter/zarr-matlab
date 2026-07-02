classdef CountingStore < zarr.stores.Store
    %COUNTINGSTORE Store wrapper that counts access patterns, for tests.

    properties
        nFullGets (1,1) double = 0
        nPartialGets (1,1) double = 0
        nSuffixGets (1,1) double = 0
    end

    properties (Access = private)
        inner
    end

    methods
        function obj = CountingStore()
            obj.inner = zarr.stores.MemoryStore();
        end

        function [data, found] = get(obj, key)
            if ~endsWith(string(key), "zarr.json")
                obj.nFullGets = obj.nFullGets + 1;
            end
            [data, found] = obj.inner.get(key);
        end

        function [data, found] = getPartial(obj, key, offset, len)
            obj.nPartialGets = obj.nPartialGets + 1;
            [data, found] = obj.inner.getPartial(key, offset, len);
        end

        function [data, found] = getSuffix(obj, key, len)
            obj.nSuffixGets = obj.nSuffixGets + 1;
            [data, found] = obj.inner.getSuffix(key, len);
        end

        function tf = exists(obj, key)
            tf = obj.inner.exists(key);
        end

        function set(obj, key, data)
            obj.inner.set(key, data);
        end

        function erase(obj, key)
            obj.inner.erase(key);
        end

        function ks = list(obj)
            ks = obj.inner.list();
        end

        function [subdirs, files] = listDir(obj, prefix)
            [subdirs, files] = obj.inner.listDir(prefix);
        end

        function resetCounts(obj)
            obj.nFullGets = 0;
            obj.nPartialGets = 0;
            obj.nSuffixGets = 0;
        end
    end
end
