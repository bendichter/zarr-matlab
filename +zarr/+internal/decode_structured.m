function records = decode_structured(bytes, info, n, endian)
%DECODE_STRUCTURED Decode n consecutive "structured" (compound record) elements.
%   bytes is a 1-by-(n*info.itemsize) uint8 vector. Returns an n-by-1
%   struct array with one field per info.fields entry (info.fields(k).Name),
%   each holding that field's decoded scalar value.
%
%   "structured" is not part of the Zarr v3 specification -- see
%   zarr.internal.dtype_info.

    arguments
        bytes (1,:) uint8
        info (1,1) struct
        n (1,1) double {mustBeNonnegative, mustBeInteger}
        endian (1,1) string {mustBeMember(endian, ["little", "big"])} = "little"
    end

    template = cell(1, 2 * numel(info.fields));
    for k = 1:numel(info.fields)
        template{2 * k - 1} = char(info.fields(k).Name);
        template{2 * k} = [];
    end
    records = repmat(struct(template{:}), n, 1);

    for j = 1:n
        recordBytes = bytes((j - 1) * info.itemsize + 1 : j * info.itemsize);
        for k = 1:numel(info.fields)
            f = info.fields(k);
            fieldBytes = recordBytes(f.Offset + 1 : f.Offset + f.Info.itemsize);
            records(j).(f.Name) = zarr.internal.decode_scalar_field(fieldBytes, f.Info, endian);
        end
    end
end
