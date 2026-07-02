classdef (Abstract) Codec
    %CODEC Base class for Zarr v3 codecs.
    %   kind is one of "array_array", "array_bytes", "bytes_bytes".
    %
    %   Subclass method contracts:
    %     array_array: [B, outShape] = encode(obj, A, shape)
    %                  A = decode(obj, B, shape)   % shape = pre-encode shape
    %                  outShape = shapeTransform(obj, shape)
    %     array_bytes: bytes = encode(obj, A, info, shape)
    %                  A = decode(obj, bytes, info, shape)
    %     bytes_bytes: bytes = encode(obj, bytes)
    %                  bytes = decode(obj, bytes)

    properties (Abstract, Constant)
        name
        kind
    end

    methods (Abstract)
        cfg = configuration(obj)  % struct for JSON, or [] for none
    end

    methods
        function txt = configJson(obj)
            %CONFIGJSON JSON text of the codec entry {"name": ..., "configuration": ...}
            cfg = obj.configuration();
            if isempty(cfg) || (isstruct(cfg) && isempty(fieldnames(cfg)))
                txt = "{""name"":""" + obj.name + """}";
            else
                txt = "{""name"":""" + obj.name + """,""configuration"":" + ...
                    string(jsonencode(cfg)) + "}";
            end
        end
    end
end
