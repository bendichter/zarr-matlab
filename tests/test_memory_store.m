classdef test_memory_store < matlab.unittest.TestCase
    methods(Test)
        function test_basic_operations(testCase)
            % Test basic store operations
            store = zarr.storage.MemoryStore();
            
            % Test set/get
            key = 'test/array';
            value = uint8([1 2 3 4]);
            store.set(key, value);
            result = store.get(key);
            testCase.verifyEqual(result, value);
            
            % Test contains
            testCase.verifyTrue(store.contains(key));
            testCase.verifyFalse(store.contains('nonexistent'));
            
            % Test get nonexistent
            result = store.get('nonexistent');
            testCase.verifyEmpty(result);
            
            % Test delete
            store.delete(key);
            testCase.verifyFalse(store.contains(key));
            result = store.get(key);
            testCase.verifyEmpty(result);
        end
        
        function test_list_operations(testCase)
            % Test listing operations
            store = zarr.storage.MemoryStore();
            
            % Create test data
            keys = {
                'root/group1/array1'
                'root/group1/array2'
                'root/group2/array3'
                'root/array4'
            };
            value = uint8([1 2 3 4]);
            for i = 1:numel(keys)
                store.set(keys{i}, value);
            end
            
            % Test list all
            result = store.list();
            testCase.verifyEqual(sort(result'), sort(keys'));
            
            % Test list_prefix
            prefix_keys = store.list_prefix('root/group1');
            testCase.verifyEqual(sort(prefix_keys'), ...
                sort({'root/group1/array1', 'root/group1/array2'}));
            
            % Test list_dir at root
            dir_keys = store.list_dir('root');
            testCase.verifyEqual(sort(dir_keys'), ...
                sort({'group1', 'group2', 'array4'}));
            
            % Test list_dir in subdirectory
            dir_keys = store.list_dir('root/group1');
            testCase.verifyEqual(sort(dir_keys'), ...
                sort({'array1', 'array2'}));
            
            % Test clear
            store.clear();
            result = store.list();
            testCase.verifyEmpty(result);
        end
        
        function test_type_validation(testCase)
            % Test input type validation
            store = zarr.storage.MemoryStore();
            
            % Test invalid key type
            testCase.verifyError(@() store.set(123, uint8([1 2 3])), ...
                'zarr:invalidType');
            
            % Test invalid value type
            testCase.verifyError(@() store.set('key', [1 2 3]), ...
                'zarr:invalidType');
            
            % Test invalid key type in get
            testCase.verifyError(@() store.get(123), ...
                'zarr:invalidType');
            
            % Test invalid key type in contains
            testCase.verifyError(@() store.contains(123), ...
                'zarr:invalidType');
            
            % Test invalid key type in delete
            testCase.verifyError(@() store.delete(123), ...
                'zarr:invalidType');
            
            % Test invalid prefix type in list_prefix
            testCase.verifyError(@() store.list_prefix(123), ...
                'zarr:invalidType');
            
            % Test invalid prefix type in list_dir
            testCase.verifyError(@() store.list_dir(123), ...
                'zarr:invalidType');
        end
        
        function test_array_storage(testCase)
            % Test storing and retrieving array data
            store = zarr.storage.MemoryStore();
            
            % Test with different array shapes
            shapes = {
                [10 1],      % Column vector
                [1 10],      % Row vector
                [5 5],       % 2D array
                [2 3 4],     % 3D array
                [1 1 1 10]   % 4D array
            };
            
            for i = 1:numel(shapes)
                shape = shapes{i};
                key = sprintf('array%d', i);
                value = uint8(reshape(1:prod(shape), shape));
                
                % Store and retrieve
                store.set(key, value);
                result = store.get(key);
                
                % Verify
                testCase.verifyEqual(result, value);
                testCase.verifyEqual(size(result), size(value));
            end
        end
        
        function test_empty_prefix(testCase)
            % Test listing with empty prefix
            store = zarr.storage.MemoryStore();
            
            % Create test data
            keys = {
                'array1'
                'group1/array2'
                'group2/subgroup/array3'
            };
            value = uint8([1 2 3 4]);
            for i = 1:numel(keys)
                store.set(keys{i}, value);
            end
            
            % Test list_prefix with empty string
            prefix_keys = store.list_prefix('');
            testCase.verifyEqual(sort(prefix_keys'), sort(keys'));
            
            % Test list_dir with empty string
            dir_keys = store.list_dir('');
            testCase.verifyEqual(sort(dir_keys'), ...
                sort({'array1', 'group1', 'group2'}));
        end
        
        function test_char(testCase)
            % Test string representation
            store = zarr.storage.MemoryStore();
            
            % Empty store
            str = char(store);
            testCase.verifyEqual(str, 'MemoryStore<0 keys>');
            
            % Store with items
            store.set('key1', uint8([1 2 3]));
            store.set('key2', uint8([4 5 6]));
            str = char(store);
            testCase.verifyEqual(str, 'MemoryStore<2 keys>');
        end
        
        function test_read_only(testCase)
            % Test read-only mode
            store = zarr.storage.MemoryStore('read_only', true);
            
            % Test write operations fail
            testCase.verifyError(@() store.set('key', uint8([1 2 3])), ...
                'zarr:store:readOnly');
            testCase.verifyError(@() store.delete('key'), ...
                'zarr:store:readOnly');
            testCase.verifyError(@() store.clear(), ...
                'zarr:store:readOnly');
            
            % Test read operations work
            testCase.verifyEmpty(store.get('key'));
            testCase.verifyFalse(store.contains('key'));
            testCase.verifyEmpty(store.list());
        end
    end
end
