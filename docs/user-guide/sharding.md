# Sharding

Small chunks give fine-grained access but, on object stores, millions of tiny
objects. The Zarr v3 `sharding_indexed` codec decouples the two: each stored
object (a **shard**) contains a grid of independently compressed **inner
chunks** plus a binary index locating them. Readers fetch only the byte
ranges of the inner chunks they need.

## Creating sharded arrays

Pass `ShardShape` (the stored-object shape) alongside `ChunkShape` (the inner
chunk shape). The shard shape must be a whole multiple of the chunk shape in
every dimension; the codec chain you pass applies to the inner chunks.

```matlab
store = zarr.stores.MemoryStore();
z = zarr.create(store, [1024 1024], "int32", Path="image", ...
    ChunkShape=[64 64], ...        % inner chunks: read granularity
    ShardShape=[512 512], ...      % stored objects: 4 total instead of 256
    Codecs={zarr.codecs.ZstdCodec(3)});

d = int32(reshape(1:1024^2, [1024 1024]));
z(:, :) = d;
assert(isequal(z(100:200, 300:400), d(100:200, 300:400)))
```

## Partial reads

Reading a region fetches the shard's index (a small ranged read at the start
or end of the object), then only the intersecting inner chunks — on a
`LocalStore` via `fseek`, on an [HttpStore](storage.md#http) via HTTP Range
requests. A one-inner-chunk read from a large shard takes milliseconds
regardless of shard size.

```matlab
tile = z(1:64, 1:64);              % touches exactly one inner chunk
assert(isequal(tile, d(1:64, 1:64)))
```

## Missing data and fills

Unwritten shards are absent entirely; unwritten (or all-fill) inner chunks
within a shard are recorded with a "missing" sentinel in the index. Both read
back as the fill value:

```matlab
zf = zarr.create(store, [8 8], "double", Path="fills", ...
    ChunkShape=[2 2], ShardShape=[4 4], FillValue=NaN);
zf(1:2, 1:2) = ones(2);
out = zf(:, :);
assert(all(isnan(out(5:8, :)), 'all'))   % missing shard
assert(all(isnan(out(3:4, 3:4)), 'all')) % missing inner chunk
```

## Options and composition

- `IndexLocation="start"` places the index at the shard's head (default
  `"end"`); both are read transparently.
- The index itself is crc32c-protected; corruption raises
  `zarr:ChecksumError`.
- Sharding is *just a codec*, so it composes: nested shards work by passing a
  `ShardingCodec` in the inner chain.

```matlab
zn = zarr.create(store, [8 8], "double", Path="nested", ...
    ChunkShape=[4 4], ShardShape=[8 8], ...
    Codecs={zarr.codecs.ShardingCodec([2 2])});
zn(:, :) = magic(8);
assert(isequal(zn(:, :), magic(8)))
```

## Writes

Writing a region that covers a whole shard encodes it directly. Partial-shard
writes read-modify-write the whole shard (the same trade-off zarr-python
makes) — for write-heavy workflows, align writes to shard boundaries.
