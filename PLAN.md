# zarr-matlab — Design & Implementation Plan

A pure-MATLAB-first library for reading and writing **Zarr v3** stores, with feature
parity against `zarr-python >= 3`, verified by round-trip interoperability tests
against the Python implementation.

## 1. Positioning & goals

- MathWorks' official [MATLAB-support-for-Zarr-files](https://github.com/mathworks/MATLAB-support-for-Zarr-files)
  (tensorstore-based) supports **Zarr v2 only**. This library targets **v3**: `zarr.json`
  metadata, the codec pipeline model, and the `sharding_indexed` codec.
- Parity target: everything `zarr-python` can read or write in v3 format, this library
  can read and write, byte-compatibly.
- Hard constraint: **no Python at runtime.** Python (zarr-python) is used only in
  tests/CI as the interoperability reference.
- Non-goals (initially): Zarr v2 format, async API, `numcodecs.*` v3 extension codecs
  (clear per-codec error; addable later via the registry), custom codec entry-point
  registry beyond a simple registration function.

## 2. Feature parity matrix (targets)

| Area | zarr-python 3 | zarr-matlab plan |
|---|---|---|
| Metadata | `zarr.json` for arrays & groups, attributes | ✅ full |
| Hierarchy | groups, nested paths, create/delete/list, tree | ✅ full |
| Data types | bool, (u)int8–64, float16/32/64, complex64/128 | ✅ full (float16 via conversion, see §5) |
| String types | variable-length UTF-8 (`string` dtype + `vlen-utf8` codec), `vlen-bytes` | ✅ MATLAB `string` / `uint8` cell |
| Array→array codecs | `transpose` | ✅ |
| Array→bytes codecs | `bytes` (endian), `sharding_indexed` | ✅ incl. partial shard reads |
| Bytes→bytes codecs | `blosc`, `gzip`, `zstd`, `crc32c` | ✅ (MEX for blosc/zstd, see §6) |
| Fill values | all dtypes incl. NaN/Inf/-0.0, complex, special JSON encodings | ✅ |
| Chunk grids | `regular` | ✅ |
| Dimension names | `dimension_names` | ✅ |
| Storage | local FS, memory, zip, remote (fsspec/obstore) | local, memory, zip; HTTP/S3 read-only later (§8) |
| Consolidated metadata | ✅ | ✅ read + write |
| Partial I/O | region read/write, resize, append | ✅ |
| Concurrency | asyncio | `parpool`/`backgroundPool` optional chunk-parallel decode (later) |

## 3. Architecture

Namespaced package `+zarr`, layered exactly like the spec:

```
+zarr/
  open.m  create.m  zeros.m  ones.m  empty.m  full.m   % convenience API
  open_group.m  open_array.m  create_group.m  create_array.m
  consolidate_metadata.m
  Array.m          % handle class; indexing, region read/write, resize, append
  Group.m          % handle class; members, attrs, create children
  Attributes.m     % dictionary-like attrs view backed by zarr.json
  +metadata/
    ArrayMetadata.m  GroupMetadata.m     % parse/serialize zarr.json
    dtypes.m                             % dtype <-> MATLAB class mapping, fill-value codec
  +codecs/
    Codec.m (abstract) ArrayArrayCodec / ArrayBytesCodec / BytesBytesCodec
    BytesCodec.m TransposeCodec.m GzipCodec.m ZstdCodec.m BloscCodec.m
    Crc32cCodec.m ShardingCodec.m VlenUtf8Codec.m VlenBytesCodec.m
    Pipeline.m     % builds/validates codec chain from metadata, encode/decode
    registry.m     % name -> constructor map; user-extensible
  +stores/
    Store.m (abstract: get, getPartial(byte range), set, delete, list, listDir, exists)
    LocalStore.m  MemoryStore.m  ZipStore.m  (HttpStore.m, S3Store.m later)
  +internal/
    chunkgrid.m    % slice <-> chunk math (all 0-based internally; convert at API edge)
    json.m         % round-trip-safe JSON (see §5.4)
    float16.m      % half <-> single conversion (vectorized, pure MATLAB)
mex/               % C sources + CMake for zarrmex_blosc / zarrmex_zstd / zarrmex_crc32c
tests/
tools/             % build scripts, packaging (.mltbx)
```

Design rules:

- **Store = flat key/value with byte-range reads.** Everything above stores speaks
  keys and bytes; `getPartial(key, offset, length)` is required for efficient
  sharding and enables remote stores later.
- **Codec pipeline mirrors the spec** (array→array → array→bytes → bytes→bytes).
  `ShardingCodec` is just an `ArrayBytesCodec` that contains its own inner pipeline,
  exactly as in zarr-python — sharding then composes for free (nested shards included).
- **All internal chunk/slice math is 0-based, C-order**, converted once at the public
  API boundary. This keeps the spec math literal and reviewable against zarr-python.

## 4. Public API sketch

```matlab
% create
z = zarr.create("weather.zarr/temp", [720 1440 100], "single", ...
    ChunkShape=[180 360 10], ...
    ShardShape=[720 1440 10], ...                 % optional; wraps codecs in sharding
    Codecs={zarr.codecs.BloscCodec(cname="zstd", clevel=5, shuffle="shuffle")}, ...
    FillValue=single(NaN), ...
    DimensionNames=["lat" "lon" "time"], ...
    Attributes=struct(units="degC"));

% write / read regions with normal MATLAB indexing (1-based, end supported)
z(:, :, 1) = frame;
block = z(1:180, 1:360, :);
data  = z(:);                  % full read, or: data = read(z);

% hierarchy
g  = zarr.open("weather.zarr");            % Group or Array, like zarr.open()
t  = g.temp;                                % member access
g.attrs("history") = "created " + string(datetime("now"));
zarr.consolidate_metadata("weather.zarr");

% other stores
m = zarr.create(zarr.stores.MemoryStore, [10 10], "int32");
z = zarr.open(zarr.stores.ZipStore("archive.zarr.zip"), path="temp");

% growth
resize(z, [720 1440 200]);
append(z, newFrames, 3);        % along dim 3
```

- `Array` uses `matlab.mixin.indexing.RedefinesParen` (R2021b+) so slicing reads only
  the needed chunks; explicit `read(z, start, count, stride)` / `write(...)` methods
  exist for h5read-style users and for stride support.
- Scalar (0-d) arrays: `z()` reads the scalar; MATLAB shape reported as `[1 1]` with
  true rank kept in `z.shape`.

## 5. MATLAB-specific design decisions

### 5.1 Dimension order — the big one
Zarr v3 chunks are C-order by default; MATLAB is column-major.
**Decision: preserve logical shape.** A python array of shape `(a, b, c)` appears in
MATLAB with `size == [a b c]`, and `arr[i, j, k]` (0-based) equals `z(i+1, j+1, k+1)`.
No h5read-style dimension flipping — `dimension_names` and shapes then match Python
exactly, which is the whole point of interop.

Implementation: decoding a C-order chunk = `reshape` into flipped shape + `permute`;
encoding is the inverse. The `transpose` codec with order `[n-1 … 0]` stores F-order
bytes — when present, the permute cancels out and MATLAB I/O is copy-free. `zarr.create`
gets an `Order="F"` sugar option that injects the transpose codec (still fully
spec-compliant and readable by zarr-python).

### 5.2 Dtype mapping
| Zarr v3 | MATLAB | Notes |
|---|---|---|
| bool | logical | |
| int8..int64 / uint8..uint64 | same | |
| float32/float64 | single/double | |
| float16 | single (by default) | pure-MATLAB vectorized half↔single converter; write path accepts `Dtype="float16"`; optional passthrough as `uint16` raw |
| complex64/128 | single/double complex | |
| string (vlen-utf8) | string array | |
| bytes (vlen-bytes) | cell of uint8 row vectors | |

### 5.3 Fill values
Full spec support: JSON `"NaN"`, `"Infinity"`, `"-Infinity"`, hex strings for exotic
NaN payloads / -0.0, `[re, im]` arrays for complex, base64 for raw bytes. This is a
classic interop failure spot — gets its own test file.

### 5.4 JSON
`jsondecode`/`jsonencode` alone lose information (int vs float, key order, >2^53
integers for uint64 fill values, `NaN` handling). Plan: thin wrapper `+internal/json.m`
that post-processes decode (and uses string-substitution or a small custom encoder for
the write path) to guarantee: uint64/int64 fill values exact, no scientific notation
for integers, stable field emission. Budget real time here; it's fiddly.

## 6. Compression strategy

Two tiers behind one codec registry (each codec name resolves to the best available
implementation: **MEX → pure MATLAB/Java**), so the library degrades gracefully
instead of failing to install. No Python at runtime, ever — Python appears only on
the test/CI side (§9).

1. **Tier 0 — no compiled code required:**
   - `gzip`/zlib via Java `java.util.zip.Deflater/Inflater` (works in every desktop
     MATLAB; a small pure-MATLAB inflate fallback is *not* planned — document JVM
     requirement).
   - `bytes`, `transpose`, `vlen-*` codecs: pure MATLAB (`typecast`/`swapbytes`).
   - `crc32c`: pure-MATLAB table-driven implementation as fallback (correctness first).
2. **Tier 1 — one MEX binary, prebuilt per platform:**
   - Single MEX target linking **c-blosc2** (which bundles zstd, lz4, zlib) — covers
     `blosc` (all cnames: lz4, lz4hc, blosclz, zstd, zlib; shuffle/bitshuffle/none),
     `zstd` (standalone codec, incl. `checksum` option), and hardware-accelerated
     `crc32c` (small C impl compiled in).
   - CMake build; GitHub Actions produces `mexw64 / mexa64 / mexmaci64 / mexmaca64`
     attached to releases and bundled in the `.mltbx`. `zarr.codecs.available()` reports
     what's usable; decode errors name the missing MEX explicitly.

Out of scope: `numcodecs.*`-prefixed v3 extension codecs (delta, bz2, lzma,
fixedscaleoffset, …) that zarr-python can emit via numcodecs wrappers. Opening such an
array raises a clear "unsupported codec 'numcodecs.delta'" error naming the codec;
individual ones can be added later as pure-MATLAB codecs (delta and fixedscaleoffset
are trivial) via the registry if users ask.

Blosc detail that bites everyone: zarr's `blosc` codec frames chunks with the 16-byte
blosc header and the v3 metadata carries `typesize` — must match zarr-python's
serialization (`shuffle` as string enum, `typesize` auto-filled from dtype at
create time).

## 7. Sharding (`sharding_indexed`)

Implemented per spec as an `ArrayBytesCodec` with config
`{chunk_shape, codecs, index_codecs, index_location}`:

- **Read:** byte-range read of the shard index (default: crc32c-checked footer, 16
  bytes per inner chunk), then ranged reads of only the inner chunks intersecting the
  request. Missing chunks (`2^64-1, 2^64-1` sentinel) → fill value. This requires
  `Store.getPartial`; on `MemoryStore` it's a slice, on `LocalStore` an `fseek`.
- **Write:** read-modify-write of whole shards by default (spec-compliant and simple);
  optimization for append-style workloads (rewrite index + append inner chunks) later.
  Document clearly that partial-shard updates rewrite the shard, same as zarr-python.
- **Nested sharding** and shard-of-one-chunk both fall out of pipeline composition —
  add tests, not code.
- `uint64` index entries: careful MATLAB arithmetic (`uint64` sentinel `intmax`), no
  doubles in offset math.

## 8. Stores

- `LocalStore` — directory on disk. Key ops via `fread`/`fwrite`; atomic writes
  (write temp + `movefile`) to match zarr-python behavior.
- `MemoryStore` — `dictionary` of `uint8` vectors; used heavily in tests.
- `ZipStore` — read via Java `java.util.zip.ZipFile` (random access + ranged reads by
  entry); write support with the constraint (same as zarr-python) that entries aren't
  rewritable — document append-only semantics.
- Later: `HttpStore` (read-only, `matlab.net.http`, Range requests → partial shard
  reads over HTTP just work) and `S3Store` (either via MATLAB's virtual filesystem
  `s3://` support in `LocalStore`-style I/O, or signed HTTP).

## 9. Testing strategy

MATLAB `matlab.unittest` class-based tests, plus a pytest suite for the Python side.

### 9.1 Pure-MATLAB unit tests
- Chunk-grid math property tests (random shapes/chunks/slices vs brute-force reference).
- Codec round-trips per codec × dtype × endianness, including empty chunks, single-element
  arrays, chunk-boundary-straddling regions, fill-value-only reads.
- Metadata round-trip: parse → serialize → parse is identity; golden `zarr.json` files.
- Sharding: index-at-start vs end, missing inner chunks, nested shards, crc32c
  corruption detection (flip a byte → expect error).

### 9.2 Python interoperability (the core requirement)
Two directions, two mechanisms:

1. **Fixture-based (runs anywhere):** `tools/make_fixtures.py` uses zarr-python to
   generate a checked-in-or-CI-generated matrix of stores + expected values saved as
   `.json`/`.npy` sidecars; MATLAB tests read and verify. A mirror
   `tools/verify_fixtures.py` reads MATLAB-written stores with zarr-python and
   compares against sidecar expectations written by MATLAB.
2. **Live in-process (when available):** MATLAB `pyenv` + `py.zarr.*` calls inside
   test classes for write-in-MATLAB→read-in-Python→write-in-Python→read-in-MATLAB
   round trips with `assumeFail`-style skip when Python/zarr isn't configured.

Test matrix (generated combinatorially, one test point each):
- dtypes: all of §5.2
- codecs: none / gzip / zstd(±checksum) / blosc{lz4, zstd, blosclz}×{noshuffle, shuffle, bitshuffle} / +crc32c / +transpose
- layout: unsharded / sharded (index at end & start) / nested shard / shard with missing chunks
- shapes: 0-d, 1-d, edge chunks not dividing shape, dim of size 1, empty array (0 in shape)
- fill values: NaN, ±Inf, -0.0, complex, extreme ints, uint64 > 2^53
- groups: nested hierarchy, attrs (unicode, nested structs/arrays), consolidated metadata
- stores: local, zip (both directions)

### 9.3 CI (GitHub Actions)
- `matlab-actions/setup-matlab` matrix: oldest-supported (proposal: **R2022b**) +
  latest, on Linux; latest-only on Windows/macOS.
- Python job: 3.11+, `zarr>=3`, runs fixture generation → MATLAB tests → pytest
  verification of MATLAB output, so every PR proves both directions.
- MEX build job per platform; artifacts feed the test jobs and releases.
- Nightly job against zarr-python `main` to catch upstream drift early.

## 10. Packaging & docs

- MATLAB Toolbox (`.mltbx`) with bundled MEX binaries per platform; File Exchange /
  Add-On Explorer listing; GitHub releases.
- Docs: `gettingStarted.mlx` live script, API reference via `help` text, a
  "coming from zarr-python / h5read" translation table, and an interop guide
  (dimension order!).
- Register the implementation on zarr.dev implementations list once conformant.

## 11. Milestones

| # | Deliverable | Scope | Status |
|---|---|---|---|
| M1 | Read path core | LocalStore/MemoryStore, metadata parsing, `bytes`+`gzip`+`transpose` codecs, pure-MATLAB `crc32c`, groups/attrs, region reads, C-order handling | ✅ done |
| M2 | Write path | create API, region writes, fill values, resize/append, atomic writes | ✅ done |
| M3 | Native codecs | MEX: blosc (all cnames/shuffles), zstd via `tools/build_mex.m` (local build against libzstd/libblosc) | ✅ codecs done; 🚧 prebuilt binaries for all four platforms + fast crc32c |
| M4 | Sharding | full read (partial, ranged) + write, nested shards, both index locations | ✅ done |
| M5 | Long tail | vlen-utf8/bytes strings, ZipStore, consolidated metadata | ✅ done (+ fast crc32c MEX) |
| M6 | Interop hardening | full §9.2 matrix green both directions (currently 34 py→ml / 33 ml→py cases + zip/consolidated fixtures), CI, nightly-vs-zarr-main | 🚧 next |
| M7 | Ship | perf pass (minimize copies, optional parallel chunk decode), docs, `.mltbx`, File Exchange | — |

Test suite: `tools/run_tests.m` — 80 matlab.unittest tests including live
bidirectional zarr-python interop (float16 done in M1, 0-d arrays done in M2).

Ordering rationale: interop fixtures arrive with M1 (read-only fixtures first), not at
M6 — every milestone lands with its Python-interop tests, M6 is completing the matrix.

## 12. Risks / open decisions

1. **Minimum MATLAB version** — proposal R2022b (needs `dictionary`? that's R2022b;
   `RedefinesParen` needs R2021b; `pyenv` fine). Dropping `dictionary` would allow
   R2021b. Decide before M1.
2. **JSON fidelity** (§5.4) — highest hidden-cost item; prototype early in M1.
3. **MEX distribution** — codesigning/notarization on macOS for prebuilt binaries;
   fallback is "compile locally" instructions + Tier 0 pure-MATLAB operation.
4. **Permute overhead** for C-order data on large chunks — mitigations: `Order="F"`
   sugar at create time, and a fast path when a chunk read is contiguous.
5. **uint64 semantics** — MATLAB saturating integer arithmetic vs numpy wraparound;
   affects only computation on values, not storage, but document it.
