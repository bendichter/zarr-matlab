classdef (Abstract) Store < handle
    %STORE Abstract key/value store backing a Zarr hierarchy.
    %   Keys are '/'-separated strings; values are uint8 row vectors.

    methods (Abstract)
        [data, found] = get(obj, key)
        tf = exists(obj, key)
        set(obj, key, data)
        erase(obj, key)
        keys = list(obj)                    % all keys, string column
        [subdirs, files] = listDir(obj, prefix)  % immediate children of prefix
    end

    methods
        function [data, found] = getPartial(obj, key, offset, len)
            %GETPARTIAL Byte-range read: len bytes starting at 0-based offset.
            %   Default falls back to a full read; subclasses override with a
            %   true ranged read where possible (required for efficient
            %   sharding).
            [full, found] = obj.get(key);
            if ~found
                data = uint8([]);
                return
            end
            first = offset + 1;
            last = min(offset + len, numel(full));
            data = full(first:last);
        end

        function [data, found] = getSuffix(obj, key, len)
            %GETSUFFIX Read the last len bytes of a value (shard index at "end").
            [full, found] = obj.get(key);
            if ~found
                data = uint8([]);
                return
            end
            data = full(max(1, numel(full) - len + 1):end);
        end
    end
end
