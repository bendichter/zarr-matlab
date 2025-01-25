function tests = test_interface
% TEST_INTERFACE Test suite for high-level Zarr interface functions
    tests = functiontests(localfunctions);
end

function test_create_basic(testCase)
    % Test basic array creation with minimal arguments
    
    % Create array with just shape and dtype
    z = zarr.create([10 10], 'double');
    
    % Verify basic properties
    testCase.verifyEqual(z.shape, [10 10]);
    testCase.verifyEqual(z.dtype, 'double');
    testCase.verifyEqual(z.zarr_format, 3);  % default format
    
    % Write and read data
    data = rand(10);
    z(:,:) = data;
    testCase.verifyEqual(z(:,:), data);
end

function test_create_with_store(testCase)
    % Test array creation with explicit store
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store and array
    store = zarr.storage.FileStore(temp_dir);
    z = zarr.create(store, [10 10], 'double');
    
    % Verify store is used
    testCase.verifyEqual(z.store, store);
end

function test_create_with_options(testCase)
    % Test array creation with various options
    
    % Create array with all options specified
    z = zarr.create([10 10], 'double', ...
        'chunks', [5 5], ...
        'compressor', zarr.codecs.ZstdCodec('level', 5), ...
        'fill_value', 0, ...
        'order', 'F', ...
        'dimension_separator', '.', ...
        'zarr_format', 2, ...
        'attributes', struct('description', 'test array'));
    
    % Verify options were applied
    testCase.verifyEqual(z.chunks, [5 5]);
    testCase.verifyEqual(z.fill_value, 0);
    testCase.verifyEqual(z.order, 'F');
    testCase.verifyEqual(z.dimension_separator, '.');
    testCase.verifyEqual(z.zarr_format, 2);
    testCase.verifyEqual(z.attrs.description, 'test array');
end

function test_group_basic(testCase)
    % Test basic group creation
    
    % Create group with default settings
    g = zarr.group();
    
    % Verify basic properties
    testCase.verifyEqual(g.path, '');
    testCase.verifyEqual(g.zarr_format, 3);
    testCase.verifyFalse(g.read_only);
end

function test_group_with_store(testCase)
    % Test group creation with explicit store
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store and group
    store = zarr.storage.FileStore(temp_dir);
    g = zarr.group(store);
    
    % Verify store is used
    testCase.verifyEqual(g.store, store);
end

function test_group_with_options(testCase)
    % Test group creation with various options
    
    % Create group with all options specified
    g = zarr.group(...
        'path', 'subgroup', ...
        'zarr_format', 2, ...
        'attributes', struct('description', 'test group'));
    
    % Verify options were applied
    testCase.verifyEqual(g.path, 'subgroup');
    testCase.verifyEqual(g.zarr_format, 2);
    testCase.verifyEqual(g.attrs.description, 'test group');
end

function test_nested_creation(testCase)
    % Test creating arrays and groups in a hierarchy
    
    % Create root group
    root = zarr.group();
    
    % Create nested groups
    g1 = root.create_group('group1');
    g2 = g1.create_group('group2');
    
    % Create arrays in different groups
    a1 = root.create_array('array1', [5 5], 'double');
    a2 = g1.create_array('array2', [5 5], 'double');
    a3 = g2.create_array('array3', [5 5], 'double');
    
    % Write data
    data = rand(5);
    a1(:,:) = data;
    a2(:,:) = 2*data;
    a3(:,:) = 3*data;
    
    % Verify hierarchy and data
    testCase.verifyEqual(root.array1(:,:), data);
    testCase.verifyEqual(root.group1.array2(:,:), 2*data);
    testCase.verifyEqual(root.group1.group2.array3(:,:), 3*data);
end

function test_open_array(testCase)
    % Test opening existing arrays
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store and array
    store = zarr.storage.FileStore(temp_dir);
    data = rand(10);
    array = zarr.create(store, [10 10], 'double', ...
        'path', 'data', ...
        'attributes', struct('description', 'test array'));
    array(:,:) = data;
    
    % Open array
    opened = zarr.open(store, 'path', 'data');
    
    % Verify array properties and data
    testCase.verifyClass(opened, 'zarr.core.Array');
    testCase.verifyEqual(opened.shape, [10 10]);
    testCase.verifyEqual(opened.dtype, 'double');
    testCase.verifyEqual(opened(:,:), data);
    testCase.verifyEqual(opened.attrs.description, 'test array');
end

function test_open_group(testCase)
    % Test opening existing groups
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store and group hierarchy
    store = zarr.storage.FileStore(temp_dir);
    root = zarr.group(store, ...
        'attributes', struct('description', 'root group'));
    g1 = root.create_group('group1');
    a1 = g1.create_array('array1', [5 5], 'double');
    
    % Write data
    data = rand(5);
    a1(:,:) = data;
    
    % Open group
    opened = zarr.open(store);
    
    % Verify group properties and contents
    testCase.verifyClass(opened, 'zarr.core.Group');
    testCase.verifyEqual(opened.attrs.description, 'root group');
    testCase.verifyTrue(opened.contains('group1'));
    testCase.verifyEqual(opened.group1.array1(:,:), data);
end

function test_open_readonly(testCase)
    % Test opening in read-only mode
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store and array with data
    store = zarr.storage.FileStore(temp_dir);
    data = rand(10);
    array = zarr.create(store, [10 10], 'double');
    array(:,:) = data;
    
    % Create new read-only store instance
    readonly_store = zarr.storage.FileStore(temp_dir, 'read_only', true);
    
    % Open array in read-only mode
    readonly = zarr.open(readonly_store);
    
    % Verify read-only status
    testCase.verifyTrue(readonly.read_only);
    
    % Verify data can be read
    testCase.verifyEqual(readonly(:,:), data);
    
    % Test write attempt
    try
        readonly(:,:) = zeros(10,10);
        testCase.verifyFail('Expected error not thrown');
    catch ME
        testCase.verifyEqual(ME.identifier, 'zarr:ReadOnlyError');
    end
end

function test_interface_errors(testCase)
    % Test error conditions in interface functions
    
    % Test invalid shape
    testCase.verifyError(@() zarr.create([], 'double'), ...
        'zarr:InvalidShape');
    
    % Test invalid dtype
    testCase.verifyError(@() zarr.create([10 10], 'invalid'), ...
        'zarr:InvalidDtype');
    
    % Test invalid parameter name
    testCase.verifyError(@() zarr.create([10 10], 'double', ...
        'invalid_param', 42), 'MATLAB:InputParser:UnmatchedParameter');
    
    % Test missing parameter value
    testCase.verifyError(@() zarr.create([10 10], 'double', ...
        'chunks'), 'MATLAB:InputParser:ArgumentValue');
    
    % Test opening non-existent path
    store = zarr.storage.FileStore(tempname);
    testCase.verifyError(@() zarr.open(store, 'path', 'nonexistent'), ...
        'zarr:PathNotFound');
    
    % Test invalid mode
    testCase.verifyError(@() zarr.open(store, 'mode', 'invalid'), ...
        'MATLAB:InputParser:ArgumentValue');
end
