%% Python Zarr Interoperability Examples
% This script demonstrates how to work with Zarr files that are shared between
% MATLAB and Python implementations.

%% Creating Data for Python Use

% Create a directory for sharing data
data_dir = 'shared_data.zarr';
if ~exist(data_dir, 'dir')
    mkdir(data_dir);
end

% Create a store with standard options for maximum compatibility
store = zarr.storage.FileStore(data_dir);

% Create a group using Zarr v2 format (widely supported)
root = zarr.group(store, ...
    'zarr_format', 2, ...  % Use v2 format for maximum compatibility
    'attributes', struct(...
        'description', 'Data for Python-MATLAB interop example', ...
        'created_by', 'MATLAB'));

%% Create Arrays with Standard Data Types

% Create Python-compatible compressor with default settings
compressor = zarr.codecs.BloscCodec(...
    'cname', 'zstd', ...    % Python's default compressor
    'clevel', 5, ...        % Python's default level
    'shuffle', true);       % Python's default setting

% Create a double array (maps to float64 in Python)
doubles = root.create_array('float64_data', [100 100], 'double', ...
    'chunks', [20 20], ...
    'compressor', compressor, ...
    'fill_value', 0);
doubles(:,:) = randn(100);

% Create a single array (maps to float32 in Python)
singles = root.create_array('float32_data', [100 100], 'single', ...
    'chunks', [20 20], ...
    'compressor', compressor, ...
    'fill_value', 0);
singles(:,:) = single(randn(100));

% Create an integer array (maps to int64 in Python)
integers = root.create_array('int64_data', [100 100], 'int64', ...
    'chunks', [20 20], ...
    'compressor', compressor, ...
    'fill_value', 0);
integers(:,:) = int64(randi([-1000 1000], 100, 100));

% Create a logical array (maps to bool in Python)
logicals = root.create_array('bool_data', [100 100], 'logical', ...
    'chunks', [20 20], ...
    'compressor', [], ...  % No compression for boolean data
    'fill_value', false);
logicals(:,:) = rand(100) > 0;

%% Add Metadata that Python Can Read

% Create a nested group for metadata
meta = root.create_group('metadata');

% Add various metadata as arrays
meta.create_array('parameters', [1 1], 'double', ...
    'attributes', struct(...
        'sampling_rate', 1000, ...
        'duration', 60, ...
        'units', 'seconds'));

% Add descriptive attributes
root.attrs.description = 'Example dataset for MATLAB-Python interoperability';
root.attrs.created = datestr(now);
root.attrs.parameters = struct(...
    'experiment_type', 'simulation', ...
    'random_seed', 12345, ...
    'version', '1.0');

%% Example of Reading the Data Back

% Reopen the store to simulate reading from Python
reopened = zarr.open(store);

% Display group structure
items = reopened.list();
disp('Dataset contents:');
for i = 1:numel(items)
    fprintf('  %s: %s\n', items(i).name, items(i).type);
end

% Read and verify data
disp('Verifying data types:');
fprintf('float64_data dtype: %s\n', reopened.float64_data.dtype);
fprintf('float32_data dtype: %s\n', reopened.float32_data.dtype);
fprintf('int64_data dtype: %s\n', reopened.int64_data.dtype);
fprintf('bool_data dtype: %s\n', reopened.bool_data.dtype);

%% Example Python Code for Reading this Data
% The following Python code can be used to read the data created above:
%
% ```python
% import zarr
% import numpy as np
%
% # Open the store
% store = zarr.open('shared_data.zarr', mode='r')
%
% # Read arrays
% float64_data = store['float64_data'][:]
% float32_data = store['float32_data'][:]
% int64_data = store['int64_data'][:]
% bool_data = store['bool_data'][:]
%
% # Read attributes
% print(store.attrs.asdict())
%
% # Access nested group
% metadata = store['metadata']
% params = metadata['parameters'].attrs.asdict()
% ```

%% Working with Arrays Created by Python
% This section demonstrates how to work with arrays that might have been
% created by Python Zarr.

% Create an example array as Python would
% (This is simulated - in reality this would be created by Python code)
py_array = zarr.create(store, [100 100], 'double', ...
    'path', 'from_python', ...
    'chunks', [20 20], ...
    'zarr_format', 2, ...  % Python typically uses v2
    'compressor', zarr.codecs.BloscCodec(...  % Python's default compression
        'cname', 'zstd', ...
        'clevel', 5, ...
        'shuffle', true), ...
    'attributes', struct(...
        'created_by', 'Python', ...
        'dtype', 'float64', ...  % Python-style dtype name
        'shape', [100 100]));

% Write some data
py_array(:,:) = randn(100);

% Read it back as if we were reading Python-created data
reopened_py = zarr.open(store, 'path', 'from_python');
data = reopened_py(:,:);

% Plot the data
figure;
imagesc(data);
title('Data from simulated Python array');
colorbar;

%% Cleanup
% In a real application, you might want to keep the data around
rmdir(data_dir, 's');
