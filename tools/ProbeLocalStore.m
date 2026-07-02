classdef ProbeLocalStore < zarr.stores.LocalStore
    %PROBELOCALSTORE LocalStore that counts get() calls after resetCount().

    properties
        nGets (1,1) double = 0
    end

    methods
        function obj = ProbeLocalStore(root)
            obj@zarr.stores.LocalStore(root);
        end

        function [data, found] = get(obj, key)
            obj.nGets = obj.nGets + 1;
            [data, found] = get@zarr.stores.LocalStore(obj, key);
        end

        function resetCount(obj)
            obj.nGets = 0;
        end
    end
end
