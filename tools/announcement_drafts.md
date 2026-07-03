# Outward-facing submission drafts (review before submitting)

Context: scalableminds/zarr-matlab (a zarrs/Rust-backed binding, same name,
started Oct 2025) also implements Zarr v3 for MATLAB. These drafts position
the two as complementary — zarrs-backed binding vs. pure-MATLAB
implementation — and lead with what distinguishes this library: full dtype
coverage, consolidated metadata, `.mltbx` install with prebuilt binaries,
and CI-proven byte-level round trips against zarr-python.

## 1. MathWorks File Exchange listing

Submit at https://www.mathworks.com/matlabcentral/fileexchange/ → "Publish"
→ "Link from GitHub". Linking the GitHub repo makes File Exchange track
GitHub releases automatically (each `v*` release, including the `.mltbx`).

**Title:** zarr-matlab — Zarr v3 for MATLAB (pure MATLAB, zarr-python interoperable)

**Summary (one line):**
Pure-MATLAB implementation of Zarr v3: chunked, compressed N-D arrays with full data-type coverage, sharding, and CI-verified byte-compatibility with zarr-python. No Python required.

**Description:**

> Zarr is a cloud-optimized format for chunked, compressed N-dimensional
> arrays, widely used in geoscience, microscopy, and neuroscience.
> zarr-matlab implements the Zarr v3 specification in pure MATLAB (with
> small optional MEX codecs for zstd/blosc compression, prebuilt for
> Linux, Windows, and Apple Silicon and bundled in the installer):
>
> - Arrays and groups with attributes, accessed with ordinary MATLAB
>   indexing — z(1:100, :, end) reads only the chunks it needs
> - Complete data-type coverage: all integer and float types incl.
>   float16, complex64/128, variable-length strings and bytes, and
>   datetime64/timedelta64
> - Compression: zstd, blosc (lz4/zstd/... with shuffle/bitshuffle),
>   gzip, crc32c checksums
> - Sharding (many small chunks per stored object) with efficient
>   ranged partial reads
> - Stores: local directories, in-memory, zip archives, and read-only
>   HTTP(S) with Range requests
> - Consolidated metadata for fast hierarchy opens on remote storage
>
> Interoperability is the core design contract: CI round-trips a 70+ case
> matrix (every dtype × codec × sharding layout) against zarr-python in
> both directions on every commit, on Linux, Windows, and macOS, back to
> MATLAB R2022b.
>
> Note: MathWorks' built-in Zarr support covers format v2; this library
> covers v3. A complementary zarrs(Rust)-backed v3 binding is also
> available from scalable minds.

**Tags:** zarr, hdf5, netcdf, cloud storage, compression, big data,
scientific data, chunked arrays, neuroscience, geoscience

---

## 2. zarr.dev implementations list (PR to zarr-developers/zarr.dev)

File: `index.md`, in the "See the following GitHub repositories" list, add
BOTH MATLAB implementations (easy merge, fair to both projects):

```diff
 * [Zarr.jl](https://github.com/meggart/Zarr.jl)
 * [ndarray.scala](https://github.com/lasersonlab/ndarray.scala)
+* [zarr-matlab](https://github.com/catalystneuro/zarr-matlab) (MATLAB, pure MATLAB v3 implementation)
+* [zarr-matlab (zarrs-backed)](https://github.com/scalableminds/zarr-matlab) (MATLAB bindings to zarrs)
```

**PR title:** Add MATLAB implementations to the repositories list

**PR body:**

> Two MATLAB implementations of Zarr v3 now exist and both are actively
> developed; this adds them to the list:
>
> - [catalystneuro/zarr-matlab](https://github.com/catalystneuro/zarr-matlab) —
>   pure-MATLAB implementation of the v3 spec (sharding with partial
>   reads, zstd/blosc/gzip/crc32c, variable-length strings,
>   datetime64, consolidated metadata). CI verifies byte-level round
>   trips against zarr-python in both directions on every commit. MIT.
> - [scalableminds/zarr-matlab](https://github.com/scalableminds/zarr-matlab)
>   — MATLAB bindings to the [zarrs](https://zarrs.dev) Rust
>   implementation. MIT.

---

## 3. Comment for zarr-developers/community#16 ("MATLAB implementation of Zarr", OPEN)

https://github.com/zarr-developers/community/issues/16

> An update for anyone tracking this: MATLAB now has good Zarr v3 coverage
> from two complementary directions.
>
> [scalableminds/zarr-matlab](https://github.com/scalableminds/zarr-matlab)
> binds the excellent [zarrs](https://zarrs.dev) Rust implementation to
> MATLAB — a thin, fast wrapper.
>
> I've just released [catalystneuro/zarr-matlab](https://github.com/catalystneuro/zarr-matlab),
> a **pure-MATLAB** implementation of the v3 spec: core arrays/groups,
> sharding with ranged partial reads, zstd/blosc/gzip/crc32c (small
> optional MEX codecs, prebuilt and bundled in a `.mltbx` for R2022b+),
> float16/complex/variable-length-string/datetime64 dtypes, zip and HTTP
> stores, and consolidated metadata. The design contract is
> interoperability: CI round-trips a 70+ case dtype × codec × sharding
> matrix against zarr-python in *both directions* on every commit.
>
> (And for completeness: MathWorks' official support covers Zarr **v2**.)
>
> The bidirectional interop test harness is deliberately
> implementation-agnostic — happy to share/adapt it if it's useful to
> other implementations, including the zarrs-backed one. Feedback and
> interop bug reports very welcome.
