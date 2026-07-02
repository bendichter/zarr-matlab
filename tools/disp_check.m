function disp_check()
s = zarr.stores.MemoryStore();
g = zarr.create_group(s, Attributes=struct('a', 1));
z = zarr.create(s, [100 200], 'single', Path='x/temp', ChunkShape=[10 20], ...
    ShardShape=[50 100], Codecs={zarr.codecs.ZstdCodec(3)}, ...
    DimensionNames=["y" "x"]);
disp(z);
disp(g);
root = zarr.open(s);
tree(root);
end
