function tests = test_store
% TEST_STORE Test suite for zarr.core.Store and implementations
    tests = functiontests(localfunctions);
end

function test_filestore_basic(testCase)
    % Test basic FileStore operations
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store
    store = zarr.storage.FileStore(temp_dir);
    
    % Test store properties
    testCase.verifyFalse(store.isreadonly());
    testCase.verifyTrue(store.supports_deletes());
    
    % Test setting and getting data
    key = 'test.array';
    data = uint8([1 2 3 4 5]);
    store.set(key, data);
    
    % Verify data was stored
    testCase.verifyTrue(store.contains(key));
    
    % Read back data
    retrieved = store.get(key);
    testCase.verifyEqual(retrieved, data);
    
    % Test listing keys
    keys = store.list();
    testCase.verifyEqual(numel(keys), 1);
    testCase.verifyEqual(keys{1}, key);
    
    % Test deleting data
    store.delete(key);
    testCase.verifyFalse(store.contains(key));
    testCase.verifyEmpty(store.list());
end

function test_filestore_nested(testCase)
    % Test FileStore with nested paths
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store
    store = zarr.storage.FileStore(temp_dir);
    
    % Create nested data
    keys = {'group1/array1', 'group1/array2', 'group2/array3'};
    data = uint8([1 2 3]);
    
    % Store data
    for i = 1:numel(keys)
        store.set(keys{i}, data);
    end
    
    % Verify all keys exist
    for i = 1:numel(keys)
        testCase.verifyTrue(store.contains(keys{i}));
    end
    
    % Test listing with prefix
    group1_keys = store.list('group1');
    testCase.verifyEqual(numel(group1_keys), 2);
    testCase.verifyTrue(all(startsWith(group1_keys, 'group1/')));
    
    % Test rmdir
    store.rmdir('group1');
    testCase.verifyFalse(store.contains('group1/array1'));
    testCase.verifyFalse(store.contains('group1/array2'));
    testCase.verifyTrue(store.contains('group2/array3'));
end

function test_filestore_key_normalization(testCase)
    % Test FileStore key normalization
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store with key normalization
    store = zarr.storage.FileStore(temp_dir, true);
    
    % Test with different path separators
    key1 = 'group1/array1';
    key2 = 'group1\array1';
    data = uint8([1 2 3]);
    
    % Store with forward slash
    store.set(key1, data);
    
    % Should be able to retrieve with backslash
    testCase.verifyTrue(store.contains(key2));
    retrieved = store.get(key2);
    testCase.verifyEqual(retrieved, data);
end

function test_filestore_errors(testCase)
    % Test FileStore error conditions
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store
    store = zarr.storage.FileStore(temp_dir);
    
    % Test getting non-existent key
    testCase.verifyEmpty(store.get('nonexistent'));
    
    % Test deleting non-existent key (should not error)
    store.delete('nonexistent');
    
    % Test invalid keys
    testCase.verifyError(@() store.set('', uint8([1])), 'MATLAB:validators:mustBeNonzeroLengthText');
end

function test_filestore_equality(testCase)
    % Test FileStore equality comparison
    
    % Create temporary directories
    temp_dir1 = tempname;
    temp_dir2 = tempname;
    mkdir(temp_dir1);
    mkdir(temp_dir2);
    cleanup1 = onCleanup(@() rmdir(temp_dir1, 's'));
    cleanup2 = onCleanup(@() rmdir(temp_dir2, 's'));
    
    % Create stores
    store1a = zarr.storage.FileStore(temp_dir1);
    store1b = zarr.storage.FileStore(temp_dir1);
    store2 = zarr.storage.FileStore(temp_dir2);
    
    % Test equality
    testCase.verifyTrue(store1a == store1b);
    testCase.verifyFalse(store1a == store2);
    
    % Test with different normalization
    store1c = zarr.storage.FileStore(temp_dir1, false);
    testCase.verifyFalse(store1a == store1c);
end
