# Blog post draft for catalystneuro.com/blog

---

## Introducing zarr-matlab: Zarr v3, natively in MATLAB

Modern scientific data lives in the cloud, and the format it increasingly
lives in is [Zarr](https://zarr.dev): chunked, compressed N-dimensional
arrays designed so you can read the piece you need instead of downloading
the file you don't. Zarr has first-class implementations in Python, Rust,
C++, Julia, and JavaScript. MATLAB — still the daily driver for a huge
share of working scientists — has been the conspicuous gap: MathWorks'
built-in support covers only the older v2 format.

Today we're releasing **[zarr-matlab](https://github.com/catalystneuro/zarr-matlab)**,
a free, open-source, pure-MATLAB implementation of the Zarr v3
specification.

### What it does

```matlab
% Create a compressed, chunked array — and index it like any MATLAB matrix
z = zarr.create("weather.zarr", [720 1440], "single", ...
    Path="temp", ChunkShape=[180 360], ...
    Codecs={zarr.codecs.ZstdCodec(5)}, FillValue=single(NaN));
z(:, :) = mydata;
block = z(1:100, end-99:end);     % reads only the chunks it touches

% Open data written by zarr-python, xarray, or any v3 implementation
g = zarr.open("https://example.org/climate.zarr");   % read-only over HTTP
tile = g.item("precipitation").read([1 1], [512 512]);
```

The feature list is the full v3 spec, not a subset:

- **Every data type**: integers, floats (including float16), complex,
  variable-length strings, and datetime64 — stored losslessly
- **Real compression**: zstd, blosc (with shuffle/bitshuffle), gzip, and
  crc32c checksums, with prebuilt binaries for Linux, Windows, and Apple
  Silicon bundled in the [File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/184186-zarr-matlab-zarr-v3-for-matlab)
  installer
- **Sharding**: thousands of small chunks stored inside each cloud object,
  read individually via byte-range requests
- **Cloud-friendly stores**: local directories, zip archives, in-memory,
  and read-only HTTP(S) — plus consolidated metadata, so opening a big
  hierarchy costs one request instead of hundreds
- **MATLAB-native ergonomics**: ordinary 1-based indexing with `end` and
  logical masks, `disp`/`tree` displays, a `.mltbx` you can double-click

### Interoperability is the contract, not a feature

The reason to store data in Zarr is that your collaborators — and your
future self — can read it from any language. So zarr-matlab treats
compatibility with [zarr-python](https://zarr.readthedocs.io/) as its
design contract: on every commit, CI has zarr-python write a 43-case
matrix covering every data type × codec × sharding layout, verifies MATLAB
reads every byte correctly, then verifies zarr-python can read everything
MATLAB writes. Both directions, every commit, on Linux, macOS, and
Windows, back to MATLAB R2022b. Even the documentation participates:
every code example in [the docs](https://catalystneuro.github.io/zarr-matlab/)
is executed by the test suite.

### Where this is going

zarr-matlab is a foundation as much as a product. Two projects are already
building on it:

- **[hdmf-zarr-matlab](https://github.com/catalystneuro/hdmf-zarr-matlab)**
  implements the [hdmf-zarr](https://github.com/hdmf-dev/hdmf-zarr)
  conventions for links and object references — the path to reading and
  writing **NWB files stored as Zarr** from MATLAB.
- **[matzarr](https://github.com/catalystneuro/matzarr)** attacks a problem
  every MATLAB lab with cloud data has: reading `.mat` files from object
  storage without downloading them. A `.mat` v7.3 file is secretly HDF5;
  matzarr indexes its chunk byte-ranges once into a small virtual-Zarr
  sidecar, after which MATLAB can open the file's entire structure in one
  request and stream exactly the slices it needs — cell arrays, structs
  and all.

If you work with array data in MATLAB — neurophysiology, imaging, climate,
anything — give it a try:

- **Install**: [File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/184186-zarr-matlab-zarr-v3-for-matlab)
  or [GitHub releases](https://github.com/catalystneuro/zarr-matlab/releases)
- **Docs**: [catalystneuro.github.io/zarr-matlab](https://catalystneuro.github.io/zarr-matlab/)
- **Issues and interop reports**: [github.com/catalystneuro/zarr-matlab](https://github.com/catalystneuro/zarr-matlab)

*CatalystNeuro builds open-source software for neuroscience data
standardization and reuse. If your lab needs help adopting cloud-native
data workflows — in Python or MATLAB — [get in touch](https://catalystneuro.com/contact).*

---

### Notes for publishing (not part of the post)

- Suggested title options: the above, or "Zarr v3 comes to MATLAB", or
  "Cloud-native arrays for MATLAB users".
- Consider embedding the logo (`docs/assets/logo.svg` / `logo-400.png`)
  and the social banner (`docs/assets/social-1280x640.png`) as the hero.
- The scalableminds zarrs-backed binding is deliberately not covered in
  the body (it's linked from the README/zarr.dev instead); add a mention
  if you prefer the ecosystem framing over the product framing.
- matzarr claims are forward-looking (pre-alpha); soften or firm up
  depending on publish date.
