function bytes = encode_structured(records, info, endian)
%ENCODE_STRUCTURED Encode n "structured" (compound record) elements as raw bytes.
%   records is an n-by-1 (or 1-by-n) struct array with one field per
%   info.fields entry (info.fields(k).Name).
%
%   "structured" is not part of the Zarr v3 specification -- see
%   zarr.internal.dtype_info.

    arguments
        records struct
        info (1,1) struct
        endian (1,1) string {mustBeMember(endian, ["little", "big"])} = "little"
    end

    records = reshape(records, [], 1);
    n = numel(records);
    bytes = zeros(1, n * info.itemsize, 'uint8');

    for j = 1:n
        for k = 1:numel(info.fields)
            f = info.fields(k);
            fieldBytes = zarr.internal.encode_scalar_field(records(j).(f.Name), f.Info, endian);
            first = (j - 1) * info.itemsize + f.Offset + 1;
            last = first + f.Info.itemsize - 1;
            bytes(first:last) = fieldBytes;
        end
    end
end
