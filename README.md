# Zarr MATLAB Implementation

A MATLAB implementation of the [Zarr](https://zarr.readthedocs.io/) array storage format, supporting both v2 and v3 specifications. This implementation provides efficient chunked, compressed N-dimensional array storage with Python compatibility.

## Features

- Support for both Zarr v2 and v3 formats
- Chunked N-dimensional array storage
- Blosc compression with configurable settings
  - ZSTD, LZ4, and ZLIB compressors
  - Compression levels 1-9
  - Optional shuffle filter
- Python compatibility with default settings matching Python Zarr
- Hierarchical group storage
- Attribute support
- Multiple storage backends

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/zarr-matlab.git
```

2. Add the zarr-matlab directory to your MATLAB path:
```matlab
addpath('/path/to/zarr-matlab');
```

## Basic Usage

### Creating Arrays

```matlab
% Create a store
store = zarr.storage.FileStore('example.zarr');

% Create a simple array
array = zarr.create(store, [1000 1000], 'double');

% Write data
array(:,:) = randn(1000);

% Create array with specific settings
array = zarr.create(store, [1000 1000], 'double', ...
    'chunks', [200 200], ...
    'compressor', zarr.codecs.BloscCodec(...
        'cname', 'zstd', ...    % Use ZSTD compressor
        'clevel', 5, ...        % Medium compression
        'shuffle', true));      % Enable shuffle filter
```

### Reading Arrays

```matlab
% Open existing array
array = zarr.open(store);

% Read entire array
data = array(:,:);

% Read partial region
subset = array(1:100, 1:100);
```

### Working with Groups

```matlab
% Create a group
root = zarr.group(store);

% Create arrays in the group
array1 = root.create_array('data1', [100 100], 'double');
array2 = root.create_array('data2', [100 100], 'single');

% Create nested groups
group1 = root.create_group('group1');
array3 = group1.create_array('data3', [100 100], 'int32');
```

### Python Compatibility

This implementation uses Blosc compression with settings that match Python Zarr's defaults:

```matlab
% Create array with Python-compatible settings
array = zarr.create(store, [1000 1000], 'double', ...
    'compressor', zarr.codecs.BloscCodec(...
        'cname', 'zstd', ...    % Python's default compressor
        'clevel', 5, ...        % Python's default level
        'shuffle', true));      % Python's default setting

% The resulting file can be read in Python:
% ```python
% import zarr
% array = zarr.open('example.zarr')
% data = array[:]
% ```
```

## Advanced Features

### Custom Compression Settings

```matlab
% Fast compression for temporary data
fast_codec = zarr.codecs.BloscCodec('cname', 'lz4', 'clevel', 3);

% High compression for archival
max_codec = zarr.codecs.BloscCodec('cname', 'zstd', 'clevel', 9);

% Compression optimized for floating-point data
float_codec = zarr.codecs.BloscCodec('shuffle', true);
```

### Attributes

```matlab
% Set array attributes
array.attrs.description = 'Example dataset';
array.attrs.units = 'meters';
array.attrs.created = datestr(now);

% Set group attributes
group.attrs.version = '1.0';
group.attrs.parameters = struct('sample_rate', 1000);
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Based on the [Zarr Specification](https://zarr.readthedocs.io/)
- Inspired by the Python reference implementation
