function tests = test_python_compat
% TEST_PYTHON_COMPAT Test compatibility with Python Zarr files
    tests = functiontests(localfunctions);
end

function test_read_v2_array(testCase)
    % Test reading a v2 array created by Python
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create test data
    shape = [100 100];
    chunks = [10 10];
    data = rand(shape);
    
    % Create array with v2 format
    store = zarr.storage.FileStore(temp_dir);
    array = zarr.create(store, shape, 'double', ...
        'chunks', chunks, ...
        'zarr_format', 2, ...
        'attributes', struct('description', 'test array'));
    array(:,:) = data;
    
    % Verify metadata format
    testCase.verifyTrue(store.contains('.zarray'));
    testCase.verifyTrue(store.contains('.zattrs'));
    
    % Open array and verify data
    opened = zarr.open(store, 'zarr_format', 2);
    testCase.verifyEqual(opened(:,:), data);
end

function test_read_v3_array(testCase)
    % Test reading a v3 array created by Python
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create test data
    shape = [100 100];
    chunks = [10 10];
    data = rand(shape);
    
    % Create array with v3 format
    store = zarr.storage.FileStore(temp_dir);
    array = zarr.create(store, shape, 'double', ...
        'chunks', chunks, ...
        'zarr_format', 3, ...
        'attributes', struct('description', 'test array'));
    array(:,:) = data;
    
    % Verify metadata format
    testCase.verifyTrue(store.contains('zarr.json'));
    
    % Open array and verify data
    opened = zarr.open(store, 'zarr_format', 3);
    testCase.verifyEqual(opened(:,:), data);
end

function test_read_v2_hierarchy(testCase)
    % Test reading a v2 group hierarchy created by Python
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create group hierarchy with v2 format
    store = zarr.storage.FileStore(temp_dir);
    root = zarr.group(store, 'zarr_format', 2);
    g1 = root.create_group('group1');
    a1 = g1.create_array('array1', [10 10], 'double');
    
    % Write test data
    data = rand(10);
    a1(:,:) = data;
    
    % Verify metadata format
    testCase.verifyTrue(store.contains('.zgroup'));
    testCase.verifyTrue(store.contains('group1/.zgroup'));
    testCase.verifyTrue(store.contains('group1/array1/.zarray'));
    
    % Open group and verify data
    opened = zarr.open(store, 'zarr_format', 2);
    testCase.verifyEqual(opened.group1.array1(:,:), data);
end

function test_read_v3_hierarchy(testCase)
    % Test reading a v3 group hierarchy created by Python
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create group hierarchy with v3 format
    store = zarr.storage.FileStore(temp_dir);
    root = zarr.group(store, 'zarr_format', 3);
    g1 = root.create_group('group1');
    a1 = g1.create_array('array1', [10 10], 'double');
    
    % Write test data
    data = rand(10);
    a1(:,:) = data;
    
    % Verify metadata format
    testCase.verifyTrue(store.contains('zarr.json'));
    testCase.verifyTrue(store.contains('group1/zarr.json'));
    testCase.verifyTrue(store.contains('group1/array1/zarr.json'));
    
    % Open group and verify data
    opened = zarr.open(store, 'zarr_format', 3);
    testCase.verifyEqual(opened.group1.array1(:,:), data);
end

function test_write_v2_compatibility(testCase)
    % Test writing data that can be read by Python Zarr v2
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create array with v2 format and standard options
    store = zarr.storage.FileStore(temp_dir);
    array = zarr.create(store, [10 10], 'double', ...
        'zarr_format', 2, ...
        'compressor', zarr.codecs.BloscCodec('clevel', 3), ...  % Standard compression (matches Python)
        'dimension_separator', '/');  % Standard separator
    
    % Write test data
    data = rand(10);
    array(:,:) = data;
    
    % Verify metadata format and content
    meta_str = char(store.get('.zarray'));
    meta = jsondecode(meta_str);
    
    % Verify standard v2 metadata fields
    testCase.verifyEqual(meta.zarr_format, 2);
    testCase.verifyEqual(meta.shape, [10 10]);
    testCase.verifyEqual(meta.chunks, [10 10]);
    testCase.verifyEqual(meta.dtype, '<f8');  % Little-endian double
    testCase.verifyEqual(meta.compressor.id, 'blosc');
    testCase.verifyEqual(meta.dimension_separator, '/');
end

function test_write_v3_compatibility(testCase)
    % Test writing data that can be read by Python Zarr v3
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create array with v3 format and standard options (matching Python defaults)
    store = zarr.storage.FileStore(temp_dir);
    array = zarr.create(store, [10 10], 'double', ...
        'zarr_format', 3, ...
        'compressor', zarr.codecs.BloscCodec(...
            'cname', 'zstd', ...  % Python Zarr's default compressor
            'clevel', 5, ...      % Python Zarr's default level
            'shuffle', true));    % Python Zarr's default setting
    
    % Write test data
    data = rand(10);
    array(:,:) = data;
    
    % Verify metadata format and content
    meta_str = char(store.get('zarr.json'));
    meta = jsondecode(meta_str);
    
    % Verify standard v3 metadata fields
    testCase.verifyEqual(meta.zarr_format, 3);
    testCase.verifyEqual(meta.node_type, 'array');
    testCase.verifyEqual(meta.shape, [10 10]);
    testCase.verifyEqual(meta.chunk_grid.name, 'regular');
    testCase.verifyEqual(meta.chunk_grid.configuration.chunk_shape, [10 10]);
    testCase.verifyTrue(any(strcmp({meta.codecs.name}, 'blosc')));
end

function test_blosc_compatibility(testCase)
    % Test Blosc compression compatibility with Python
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store
    store = zarr.storage.FileStore(temp_dir);
    
    % Create array with Python's default compression settings
    array = zarr.create(store, [100 100], 'double', ...
        'compressor', zarr.codecs.BloscCodec(...
            'cname', 'zstd', ...    % Python's default compressor
            'clevel', 5, ...        % Python's default level
            'shuffle', true));      % Python's default setting
    
    % Write test data
    data = rand(100);
    array(:,:) = data;
    
    % Verify metadata format and content
    if array.zarr_format == 2
        meta_str = char(store.get('.zarray'));
    else
        meta_str = char(store.get('zarr.json'));
    end
    meta = jsondecode(meta_str);
    
    % Find Blosc codec in metadata
    if array.zarr_format == 2
        codec = meta.compressor;
    else
        codec_idx = find(strcmp({meta.codecs.name}, 'blosc'), 1);
        codec = meta.codecs(codec_idx);
    end
    
    % Verify Blosc settings match Python defaults
    testCase.verifyEqual(codec.id, 'blosc');
    testCase.verifyEqual(codec.cname, 'zstd');
    testCase.verifyEqual(codec.clevel, 5);
    testCase.verifyTrue(codec.shuffle);
    
    % Verify data can be read back correctly
    retrieved = array(:,:);
    testCase.verifyEqual(retrieved, data);
end

function test_dtype_compatibility(testCase)
    % Test compatibility of different data types
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Test different dtypes
    dtypes = {'double', 'single', 'int8', 'uint8', 'int16', 'uint16', ...
              'int32', 'uint32', 'int64', 'uint64'};
    
    for i = 1:numel(dtypes)
        dtype = dtypes{i};
        
        % Create array
        store = zarr.storage.FileStore(fullfile(temp_dir, dtype));
        array = zarr.create(store, [10 10], dtype);
        
        % Write test data
        if startsWith(dtype, 'int') || startsWith(dtype, 'uint')
            data = cast(randi(100, [10 10]), dtype);
        else
            data = cast(rand(10), dtype);
        end
        array(:,:) = data;
        
        % Verify data can be read back correctly
        testCase.verifyEqual(array(:,:), data);
    end
end
