classdef GroupMetadata
    %GROUPMETADATA Parsed Zarr v3 group metadata (zarr.json).

    properties
        attributes struct = struct()
        consolidated = []   % containers.Map: node path -> raw zarr.json text, or []
    end

    methods (Static)
        function obj = fromJsonText(txt)
            txt = char(txt);
            m = jsondecode(txt);
            if ~isfield(m, 'zarr_format') || m.zarr_format ~= 3
                error("zarr:InvalidMetadata", "Only zarr_format 3 is supported.");
            end
            if ~isfield(m, 'node_type') || ~strcmp(m.node_type, 'group')
                error("zarr:InvalidMetadata", "Expected node_type 'group'.");
            end
            obj = zarr.metadata.GroupMetadata();
            if isfield(m, 'attributes') && isstruct(m.attributes)
                obj.attributes = m.attributes;
            end
            if isfield(m, 'consolidated_metadata') && ~isempty(m.consolidated_metadata)
                % Re-extract with exact keys: jsondecode mangles path keys.
                [rk, rv] = zarr.internal.json_object_entries(txt);
                cIdx = find(rk == "consolidated_metadata", 1);
                [ck, cv] = zarr.internal.json_object_entries(rv(cIdx));
                mIdx = find(ck == "metadata", 1);
                if ~isempty(mIdx)
                    [paths, texts] = zarr.internal.json_object_entries(cv(mIdx));
                    obj.consolidated = containers.Map('KeyType', 'char', 'ValueType', 'any');
                    for i = 1:numel(paths)
                        obj.consolidated(char(paths(i))) = texts(i);
                    end
                end
            end
        end
    end

    methods
        function txt = toJsonText(obj)
            txt = """zarr_format"":3,""node_type"":""group""";
            if ~isempty(fieldnames(obj.attributes))
                txt = txt + ",""attributes"":" + string(jsonencode(obj.attributes));
            end
            if ~isempty(obj.consolidated)
                paths = sort(string(obj.consolidated.keys())');
                entries = strings(numel(paths), 1);
                for i = 1:numel(paths)
                    entries(i) = string(jsonencode(char(paths(i)))) + ":" + ...
                        string(obj.consolidated(char(paths(i))));
                end
                txt = txt + ",""consolidated_metadata"":{""kind"":""inline""," + ...
                    """must_understand"":false,""metadata"":{" + ...
                    strjoin(entries, ",") + "}}";
            end
            txt = "{" + txt + "}";
        end
    end
end
