classdef TransposeCodec < zarr.codecs.Codec
    %TRANSPOSECODEC The Zarr v3 "transpose" codec.
    %   order is the 0-based permutation from the spec: output dimension i of
    %   the encoded array is input dimension order(i+1).

    properties (Constant)
        name = "transpose"
        kind = "array_array"
    end

    properties
        order (1,:) double
    end

    methods
        function obj = TransposeCodec(order)
            order = reshape(double(order), 1, []);
            if ~isequal(sort(order), 0:numel(order) - 1)
                error("zarr:CodecError", ...
                    "transpose order must be a permutation of 0..R-1.");
            end
            obj.order = order;
        end

        function cfg = configuration(obj)
            cfg = struct('order', obj.order);
        end

        function txt = configJson(obj)
            % Override: a rank-1 order like [0] must serialize as [0], not 0.
            txt = "{""name"":""transpose"",""configuration"":{""order"":[" + ...
                strjoin(string(obj.order), ",") + "]}}";
        end

        function outShape = shapeTransform(obj, shape)
            outShape = shape(obj.order + 1);
        end

        function [B, outShape] = encode(obj, A, shape)
            outShape = obj.shapeTransform(shape);
            if numel(shape) >= 2
                B = permute(A, obj.order + 1);
            else
                B = A;
            end
        end

        function A = decode(obj, B, shape)
            if numel(shape) >= 2
                A = ipermute(B, obj.order + 1);
            else
                A = B;
            end
        end
    end

    methods (Static)
        function obj = fromConfig(cfg)
            obj = zarr.codecs.TransposeCodec(reshape(cfg.order, 1, []));
        end
    end
end
