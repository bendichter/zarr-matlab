%% Basic Zarr Usage Examples
% This script demonstrates basic usage of the MATLAB Zarr implementation.

%% Creating Arrays

% Create a directory for storing data
data_dir = 'example.zarr';
if ~exist(data_dir, 'dir')
    mkdir(data_dir);
end

% Create a store
store = zarr.storage.FileStore(data_dir);

% Create a simple array with default settings
array1 = zarr.create(store, [1000 1000], 'double', ...
    'path', 'simple_array');

% Write some data
data = randn(1000);
array1(:,:) = data;

% Create an array with specific chunk size and compression
array2 = zarr.create(store, [1000 1000], 'double', ...
    'path', 'compressed_array', ...
    'chunks', [200 200], ...
    'compressor', zarr.codecs.BloscCodec(...  % Using Blosc compression
        'cname', 'zstd', ...    % Use ZSTD compressor
        'clevel', 5, ...        % Medium compression level
        'shuffle', true));      % Enable shuffle filter

% Write data to compressed array
array2(:,:) = data;

%% Reading Arrays

% Read entire arrays
data1 = array1(:,:);
data2 = array2(:,:);

% Read partial regions
subset1 = array1(1:100, 1:100);
subset2 = array2(1:100, 1:100);

%% Advanced Array Creation

% Create an array with specific settings for scientific data
science_array = zarr.create(store, [1000 1000], 'single', ...
    'path', 'science_data', ...
    'chunks', [100 100], ...
    'compressor', zarr.codecs.BloscCodec(...
        'cname', 'lz4', ...     % Fast compression
        'clevel', 3, ...        % Lower compression for speed
        'shuffle', true), ...   % Enable shuffle for floating-point data
    'fill_value', NaN, ...     % Use NaN for missing data
    'order', 'F');             % Column-major order for MATLAB efficiency

% Write some data with missing values
data = randn(1000, 'single');
data(data < 0) = NaN;  % Set negative values to NaN
science_array(:,:) = data;

% Create an array optimized for integer time series
timeseries = zarr.create(store, [1000000 10], 'int16', ...
    'path', 'timeseries', ...
    'chunks', [10000 10], ...     % Chunk along time dimension
    'compressor', zarr.codecs.BloscCodec(...
        'cname', 'zstd', ...      % Good compression for integers
        'clevel', 7, ...          % Higher compression for archival
        'shuffle', true));        % Enable shuffle for better compression

% Write some example time series data
for i = 1:10
    timeseries(:,i) = int16(sin(linspace(0, 10*pi, 1000000))*1000 + ...
        randn(1, 1000000)*100);
end

%% Working with Groups

% Create a group
group = zarr.group(store, 'path', 'results');

% Create arrays within the group
for i = 1:5
    % Create array with different compression settings based on data type
    if mod(i, 2) == 0
        % Integer data with high compression
        array = group.create_array(sprintf('data%d', i), [100 100], 'int32', ...
            'compressor', zarr.codecs.BloscCodec(...
                'cname', 'zstd', ...
                'clevel', 9, ...    % Maximum compression
                'shuffle', true));
        array(:,:) = randi([-100 100], 100, 100);
    else
        % Floating-point data with balanced settings
        array = group.create_array(sprintf('data%d', i), [100 100], 'double', ...
            'compressor', zarr.codecs.BloscCodec(...
                'cname', 'lz4', ...
                'clevel', 5, ...    % Medium compression
                'shuffle', true));
        array(:,:) = randn(100);
    end
end

%% Array Information

% Display array info
disp('Array information:');
disp(array1);
disp('Compressed array information:');
disp(array2);

% Get array properties
fprintf('Shape: [%s]\n', strjoin(string(array1.shape), ' '));
fprintf('Chunks: [%s]\n', strjoin(string(array1.chunks), ' '));
fprintf('Data type: %s\n', array1.dtype);

%% Cleanup
% In a real application, you might want to keep the data around
rmdir(data_dir, 's');
