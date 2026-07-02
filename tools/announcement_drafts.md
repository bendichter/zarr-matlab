# Outward-facing submission drafts (review before submitting)

## 1. MathWorks File Exchange listing

Submit at https://www.mathworks.com/matlabcentral/fileexchange/ → "Publish"
→ "Link from GitHub". Linking the GitHub repo makes File Exchange track
GitHub releases automatically (each `v*` release, including the `.mltbx`).

**Title:** zarr-matlab — Zarr v3 for MATLAB

**Summary (one line):**
Read and write Zarr v3 chunked, compressed N-D arrays natively in MATLAB — byte-compatible with zarr-python, no Python required.

**Description:**

> Zarr is a cloud-optimized format for chunked, compressed N-dimensional
> arrays, widely used in geoscience, microscopy, and neuroscience.
> zarr-matlab is a pure-MATLAB implementation of the Zarr v3 specification:
>
> - Arrays and groups with attributes, created/read with ordinary MATLAB
>   indexing (z(1:100, :) reads only the chunks it needs)
> - All core data types incl. float16, complex, variable-length strings, and
>   datetime64/timedelta64
> - Compression: zstd, blosc (lz4/zstd/…, with shuffle/bitshuffle), gzip,
>   crc32c checksums — prebuilt binaries included for Linux, Windows, and
>   Apple Silicon
> - Sharding (many small chunks per stored object) with efficient partial
>   reads
> - Stores: local directories, in-memory, zip archives, and read-only HTTP(S)
>   with ranged requests
> - Consolidated metadata for fast hierarchy opens on cloud storage
>
> Every release is verified byte-for-byte against zarr-python across a
> 70+ case interoperability matrix (both read and write directions).
> MathWorks' built-in Zarr support covers format v2; this library covers v3.
>
> Requires R2022b+. Install the .mltbx or clone from GitHub.

**Tags:** zarr, hdf5, netcdf, cloud storage, compression, big data,
scientific data, chunked arrays, neuroscience, geoscience

---

## 2. zarr.dev implementations list (PR to zarr-developers/zarr.dev)

File: `index.md`, in the "See the following GitHub repositories" list, add:

```diff
 * [Zarr.jl](https://github.com/meggart/Zarr.jl)
 * [ndarray.scala](https://github.com/lasersonlab/ndarray.scala)
+* [zarr-matlab](https://github.com/bendichter/zarr-matlab)
```

**PR title:** Add zarr-matlab to the implementations list

**PR body:**

> zarr-matlab (https://github.com/bendichter/zarr-matlab) is a MATLAB
> implementation of the Zarr v3 spec: core arrays/groups, sharding with
> partial reads, blosc/zstd/gzip/crc32c codecs, variable-length strings,
> and consolidated metadata. CI verifies byte-level round trips against
> zarr-python (both directions) on every commit. MIT licensed.

---

## 3. Comment for zarr-developers/community#16 ("MATLAB implementation of Zarr", OPEN)

https://github.com/zarr-developers/community/issues/16

> For anyone still tracking this: I've released
> [zarr-matlab](https://github.com/bendichter/zarr-matlab), a MATLAB
> implementation of **Zarr v3** (complementing MathWorks' official v2
> support). It covers the core spec plus sharding with partial reads,
> blosc/zstd/gzip/crc32c, variable-length strings, zip/HTTP stores, and
> consolidated metadata, with CI that round-trips every dtype × codec ×
> sharding combination against zarr-python in both directions. Prebuilt
> binaries ship in a `.mltbx` for R2022b+. Feedback and interop bug
> reports very welcome.
