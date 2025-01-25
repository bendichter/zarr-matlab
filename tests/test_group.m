function tests = test_group
% TEST_GROUP Test suite for zarr.core.Group
    tests = functiontests(localfunctions);
end

function test_group_creation(testCase)
    % Test basic group creation
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store
    store = zarr.storage.FileStore(temp_dir);
    
    % Create group
    group = zarr.core.Group(store, '');
    
    % Verify properties
    testCase.verifyFalse(group.read_only);
    testCase.verifyEqual(group.path, '');
end

function test_group_arrays(testCase)
    % Test creating and accessing arrays in a group
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store and group
    store = zarr.storage.FileStore(temp_dir);
    group = zarr.core.Group(store, '');
    
    % Create arrays
    array1 = group.create_array('data1', [10 10], 'double');
    array2 = group.create_array('data2', [5 5], 'int32');
    
    % Write data
    data1 = rand(10);
    data2 = int32(randi(100, 5));
    array1(:,:) = data1;
    array2(:,:) = data2;
    
    % Access arrays through group
    testCase.verifyTrue(group.contains('data1'));
    testCase.verifyTrue(group.contains('data2'));
    
    % Print metadata for debugging
    if store.contains('data1/zarr.json')
        disp('data1/zarr.json:');
        disp(char(store.get('data1/zarr.json')));
    end
    if store.contains('data1/.zarray')
        disp('data1/.zarray:');
        disp(char(store.get('data1/.zarray')));
    end
    
    % Verify data
    testCase.verifyEqual(group.data1(:,:), data1);
    testCase.verifyEqual(group.data2(:,:), data2);
end

function test_nested_groups(testCase)
    % Test nested group hierarchy
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store and root group
    store = zarr.storage.FileStore(temp_dir);
    root = zarr.core.Group(store, '');
    
    % Create nested groups
    group1 = root.create_group('group1');
    group2 = group1.create_group('group2');
    
    % Create arrays in different groups
    array1 = root.create_array('data1', [5 5], 'double');
    array2 = group1.create_array('data2', [5 5], 'double');
    array3 = group2.create_array('data3', [5 5], 'double');
    
    % Write data
    data = rand(5);
    array1(:,:) = data;
    array2(:,:) = 2*data;
    array3(:,:) = 3*data;
    
    % Print metadata for debugging
    if store.contains('group1/data2/zarr.json')
        disp('group1/data2/zarr.json:');
        disp(char(store.get('group1/data2/zarr.json')));
    end
    if store.contains('group1/data2/.zarray')
        disp('group1/data2/.zarray:');
        disp(char(store.get('group1/data2/.zarray')));
    end
    
    % Access through hierarchy
    testCase.verifyEqual(root.data1(:,:), data);
    testCase.verifyEqual(root.group1.data2(:,:), 2*data);
    testCase.verifyEqual(root.group1.group2.data3(:,:), 3*data);
end

function test_group_listing(testCase)
    % Test listing group contents
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store and group
    store = zarr.storage.FileStore(temp_dir);
    group = zarr.core.Group(store, '');
    
    % Create arrays and groups
    group.create_array('array1', [5 5], 'double');
    group.create_array('array2', [5 5], 'double');
    group.create_group('group1');
    group.create_group('group2');
    
    % List contents
    items = group.list();
    
    % Print all store keys for debugging
    disp('All store keys:');
    keys = store.list('');
    for i = 1:numel(keys)
        disp(keys{i});
    end
    
    % Verify listing
    testCase.verifyEqual(numel(items), 4);
    
    % Count arrays and groups
    array_count = sum(strcmp({items.type}, 'array'));
    group_count = sum(strcmp({items.type}, 'group'));
    testCase.verifyEqual(array_count, 2);
    testCase.verifyEqual(group_count, 2);
end

function test_group_attributes(testCase)
    % Test group attributes
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store
    store = zarr.storage.FileStore(temp_dir);
    
    % Create group with attributes
    attrs = struct('description', 'test group', ...
                  'created', datestr(now), ...
                  'tags', {{'test', 'example'}});
    group = zarr.core.Group(store, '', 'attributes', attrs);
    
    % Verify attributes
    stored_attrs = group.attrs;
    testCase.verifyEqual(stored_attrs.description, attrs.description);
    testCase.verifyEqual(stored_attrs.created, attrs.created);
    testCase.verifyEqual(stored_attrs.tags, attrs.tags);
end

function test_group_errors(testCase)
    % Test group error conditions
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store and group
    store = zarr.storage.FileStore(temp_dir);
    group = zarr.core.Group(store, '');
    
    % Test creating array with existing name
    group.create_array('test', [5 5], 'double');
    testCase.verifyError(@() group.create_array('test', [10 10], 'double'), ...
        'zarr:KeyError');
    
    % Test creating group with existing name
    testCase.verifyError(@() group.create_group('test'), ...
        'zarr:KeyError');
    
    % Test accessing non-existent item
    testCase.verifyError(@() group.nonexistent, ...
        'zarr:KeyError');
end

function test_group_formats(testCase)
    % Test group creation with different Zarr formats
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store
    store = zarr.storage.FileStore(temp_dir);
    
    % Test v2 format
    group_v2 = zarr.core.Group(store, 'v2', 'zarr_format', 2);
    testCase.verifyEqual(group_v2.zarr_format, 2);
    
    % Test v3 format
    group_v3 = zarr.core.Group(store, 'v3', 'zarr_format', 3);
    testCase.verifyEqual(group_v3.zarr_format, 3);
    
    % Verify format compatibility
    array_v2 = group_v2.create_array('data', [5 5], 'double');
    array_v3 = group_v3.create_array('data', [5 5], 'double');
    testCase.verifyEqual(array_v2.zarr_format, 2);
    testCase.verifyEqual(array_v3.zarr_format, 3);
end
