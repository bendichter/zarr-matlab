# Using with Python

Interoperability with [zarr-python](https://zarr.readthedocs.io/) is this
library's design contract: CI round-trips a 70+ case matrix (every dtype ×
codec × sharding layout) in both directions on every commit. This page
covers the conventions you need to move data between the two.

## Shapes are preserved, not flipped

A zarr array of shape `(a, b, c)` in Python has `size(z) == [a b c]` in
MATLAB, and `arr[i, j, k]` in Python equals `z(i+1, j+1, k+1)` in MATLAB —
only the 0-based → 1-based shift changes. `dimension_names` line up
one-to-one.

!!! note
    This differs from MATLAB's `h5read`, which reverses dimension order.
    zarr-matlab keeps the logical shape identical on both sides.

Chunks are stored C-order per the spec, so MATLAB pays a permute per chunk.
If a dataset is written and read mainly from MATLAB, create it with
`Order="F"` — a spec-standard transpose codec that makes MATLAB I/O copy-free
while remaining fully readable from Python.

## Rank mapping

- rank-2+: same shape both sides
- rank-1: MATLAB column vector (`[n 1]`)
- rank-0 (scalar): read/write with `z()` in MATLAB, `arr[()]` in Python

## Worked example

MATLAB writes:

```matlab
z = zarr.create("shared.zarr", [4 6], "single", Path="a", ...
    ChunkShape=[2 3], Codecs={zarr.codecs.ZstdCodec(3)}, ...
    DimensionNames=["y" "x"], Attributes=struct(units="mV"));
z(:, :) = single(reshape(1:24, [4 6]));
assert(z(2, 3) == single(2 + 4 * 2))    % row 2, col 3 -> value 10
```

Python reads (not executed here):

```python
import zarr
a = zarr.open("shared.zarr")["a"]
assert a.shape == (4, 6)
assert a[1, 2] == 10.0          # same element as z(2, 3)
assert a.attrs["units"] == "mV"
```

And the reverse — anything zarr-python writes (including with its default
zstd compressor, sharding, or string dtypes) opens in MATLAB with
`zarr.open`.

## Type correspondence

See [Data types](data-types.md) for the full table. The subtleties:

- **float16** is converted losslessly to/from `single`.
- **datetime64/timedelta64** are exposed as exact int64 ticks — MATLAB's
  `datetime` cannot represent nanosecond timestamps exactly.
- **Fill values** round-trip exactly, including `NaN` payload bit patterns,
  `-0.0`, and 64-bit integers beyond 2^53.
- **Attributes** with non-identifier keys are normalized on the MATLAB side
  (struct field-name rules).

## Sharing one environment

Nothing in zarr-matlab uses Python at runtime — the two libraries only meet
at the bytes on disk. If you do run both in one MATLAB session (e.g. via
`pyenv`), they can read each other's stores concurrently; just avoid
concurrent *writes* to the same array, which Zarr itself does not coordinate.
