# Compression and codecs

A Zarr v3 codec chain has three stages: optional array→array codecs
(`transpose`), exactly one array→bytes serializer (`bytes`, or `vlen-*` for
variable-length types — inserted automatically), and any number of
bytes→bytes codecs (compressors and checksums).

Pass codec objects to `zarr.create`; order within a stage is preserved:

```matlab
store = zarr.stores.MemoryStore();
z = zarr.create(store, [100 100], "double", ChunkShape=[50 50], Path="a", ...
    Codecs={zarr.codecs.ZstdCodec(5), zarr.codecs.Crc32cCodec()});
z(:, :) = randn(100);
assert(isequal(size(z(:, :)), [100 100]))
```

## Available codecs

| Codec | Constructor | Notes |
|---|---|---|
| zstd | `zarr.codecs.ZstdCodec(level, checksum)` | levels −131072…22, default 0; zarr-python's default compressor |
| blosc | `zarr.codecs.BloscCodec(cname=…, clevel=…, shuffle=…)` | cname: `lz4`, `lz4hc`, `blosclz`, `zstd`, `zlib`; shuffle: `noshuffle`/`shuffle`/`bitshuffle`; typesize auto-filled from the dtype |
| gzip | `zarr.codecs.GzipCodec(level)` | levels 0–9, default 5; pure Java, no MEX needed |
| crc32c | `zarr.codecs.Crc32cCodec()` | 4-byte checksum, verified on read |
| transpose | `zarr.codecs.TransposeCodec(order)` | 0-based dimension permutation |
| bytes | `zarr.codecs.BytesCodec(endian)` | serializer; `"little"` (default) or `"big"` |

```matlab
zb = zarr.create(store, [64 64], "single", ChunkShape=[32 32], Path="b", ...
    Codecs={zarr.codecs.BloscCodec(cname="lz4", clevel=9, shuffle="shuffle")});
p = single(peaks(64));
zb(:, :) = p;
assert(isequal(zb(:, :), p))
```

## MEX codecs

`zstd` and `blosc` (and a fast `crc32c`) are implemented as small MEX
binaries. Toolbox installs include them prebuilt for Linux, Windows, and
Apple Silicon; source installs build them once:

```text
>> run tools/build_mex.m     % needs a C compiler + libzstd / libblosc
```

Everything else — including gzip — works without them; opening data that
needs a missing MEX raises `zarr:MissingMex` naming the codec. Note that
**zarr-python's default compressor is zstd**, so most Python-written v3 data
needs the MEX.

## Column-major storage (`Order="F"`)

Zarr chunks are C-order (row-major) by default; MATLAB memory is
column-major, so encoding/decoding involves a permute. Passing `Order="F"`
inserts a spec-standard transpose codec so chunks are stored column-major —
copy-free for MATLAB, still perfectly readable by zarr-python:

```matlab
zf = zarr.create(store, [40 60], "double", ChunkShape=[20 30], ...
    Path="forder", Order="F");
zf(:, :) = rand(40, 60);
assert(isequal(size(zf(1:10, 1:10)), [10 10]))
```

## Performance

Measured on an M1 Mac (R2024b), 200 MB float64, 500×500 chunks
(`tools/bench.m`):

| config | write MB/s | read MB/s | stored MB |
|---|---|---|---|
| raw (bytes only) | 329 | 1237 | 200.0 |
| gzip-1 (Java) | 40 | 112 | 179.0 |
| zstd-3 (MEX) | 302 | 593 | 183.5 |
| blosc zstd-3 shuffle (MEX) | 315 | 889 | 151.4 |
| zstd-3 sharded | 395 | 557 | 183.5 |

Recommendation: **blosc(zstd) with shuffle** for numeric data — best
compression *and* fastest decompression. Reserve gzip for environments where
the MEX binaries cannot be used.
