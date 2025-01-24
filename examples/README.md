# Zarr MATLAB Examples

This directory contains example scripts demonstrating how to use the Zarr MATLAB library. Each script is thoroughly documented and showcases different aspects of the library's functionality.

## Available Examples

### basic_usage.m
A comprehensive introduction to Zarr MATLAB functionality, including:
- Creating and working with arrays
- Using groups and hierarchies
- Persistent storage with FileStore
- Working with different data types
- Memory-efficient processing of large arrays
- Using arrays in computations

### python_interop.m
Demonstrates interoperability between MATLAB and Python Zarr implementations:
- Creating Zarr data that can be read by Python
- Working with standard data types
- Adding metadata in Python-compatible format
- Reading data that could have been created by Python
- Includes example Python code for verification

## Running the Examples

1. Ensure you have added the zarr-matlab directory to your MATLAB path:
```matlab
addpath('/path/to/zarr-matlab');
```

2. Navigate to the examples directory:
```matlab
cd('/path/to/zarr-matlab/examples');
```

3. Run an example script:
```matlab
% Run basic usage examples
basic_usage

% Run Python interoperability examples
python_interop
```

## Notes

- The examples create temporary files in the current directory. These are cleaned up automatically at the end of the scripts.
- Some examples create visualizations using MATLAB's plotting functions.
- The Python interoperability example includes Python code snippets that can be used to verify the data from Python.

## Requirements

- MATLAB (versions from last 2 years supported)
- Zarr MATLAB library properly installed
- For Python interoperability examples:
  - Python with zarr package installed (optional, for verification)
  - NumPy (optional, for verification)

## Additional Resources

- Main library documentation in the `docs` directory
- Test files in the `tests` directory provide additional usage examples
- Python Zarr documentation: https://zarr.readthedocs.io/

## Contributing

If you create additional examples that might be useful for other users, please consider contributing them back to the project. See the main README.md for contribution guidelines.
