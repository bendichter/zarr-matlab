function codecs = fill_blosc_typesize(codecs, itemsize)
%FILL_BLOSC_TYPESIZE Set typesize on Blosc codecs that were created without
%   one (typesize == 0), recursing into sharding codec chains.

if isnan(itemsize)
    itemsize = 1;  % variable-length dtypes: blosc sees an opaque byte stream
end
for i = 1:numel(codecs)
    c = codecs{i};
    if isa(c, 'zarr.codecs.BloscCodec') && c.typesize == 0
        c.typesize = itemsize;
        codecs{i} = c;
    elseif isa(c, 'zarr.codecs.ShardingCodec')
        c.codecs = zarr.internal.fill_blosc_typesize(c.codecs, itemsize);
        codecs{i} = c;
    end
end
end
