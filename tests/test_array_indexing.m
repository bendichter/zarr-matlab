classdef test_array_indexing < matlab.unittest.TestCase
    % TEST_ARRAY_INDEXING Unit tests for array indexing operations
    
    methods (Test)
        function test_basic_array_operations(testCase)
            % Test basic array operations
            store = zarr.storage.FileStore('test_array');
            shape = [10 10];
            chunks = [5 5];
            
            % Create array
            array = zarr.core.Array(store, '', shape, 'double', ...
                'chunks', chunks, 'compressor', []);
            
            % Test writing and reading single value
            subs = {1, 1};
            indices = array.indexer.parse_subscripts(subs);
            [chunk_coords, chunk_idx] = array.grid.get_chunk_coords(indices);
            fprintf('Single point indices: %s\n', mat2str([indices{:}]));
            fprintf('Single point chunk coords: %s\n', mat2str(chunk_coords));
            fprintf('Single point chunk idx: %s\n', mat2str(chunk_idx));
            
            array(1,1) = 42;
            value = array(1,1);
            testCase.verifyEqual(value, 42);
            
            % Test writing and reading block
            subs = {1:3, 1:3};
            indices = array.indexer.parse_subscripts(subs);
            [chunk_coords, chunk_idx] = array.grid.get_chunk_coords(indices);
            fprintf('Block indices: %s, %s\n', mat2str(indices{1}), mat2str(indices{2}));
            fprintf('Block chunk coords: %s\n', mat2str(chunk_coords));
            fprintf('Block chunk idx: %s\n', mat2str(chunk_idx));
            
            data = reshape(1:9, [3 3]);
            array(1:3, 1:3) = data;
            block = array(1:3, 1:3);
            testCase.verifyEqual(block, data);
            
            % Test writing and reading across chunks
            subs = {3:6, 3:6};
            indices = array.indexer.parse_subscripts(subs);
            [chunk_coords, chunk_idx] = array.grid.get_chunk_coords(indices);
            fprintf('Cross-chunk indices: %s, %s\n', mat2str(indices{1}), mat2str(indices{2}));
            fprintf('Cross-chunk chunk coords: %s\n', mat2str(chunk_coords));
            fprintf('Cross-chunk chunk idx: %s\n', mat2str(chunk_idx));
            
            data = reshape(1:16, [4 4]);
            array(3:6, 3:6) = data;
            block = array(3:6, 3:6);
            testCase.verifyEqual(block, data);
            
            % Test writing and reading full array
            data = reshape(1:100, shape);
            array(:,:) = data;
            full = array(:,:);
            testCase.verifyEqual(full, data);
        end
        
        function test_array_slicing(testCase)
            % Test array slicing operations
            store = zarr.storage.FileStore('test_array');
            shape = [10 10];
            chunks = [5 5];
            
            % Create array
            array = zarr.core.Array(store, '', shape, 'double', ...
                'chunks', chunks, 'compressor', []);
            
            % Fill with test data
            data = reshape(1:100, shape);
            array(:,:) = data;
            
            % Test row slice
            row = array(5,:);
            testCase.verifyEqual(row, data(5,:));
            
            % Test column slice
            col = array(:,5);
            testCase.verifyEqual(col, data(:,5));
            
            % Test block slice
            block = array(2:4, 6:8);
            testCase.verifyEqual(block, data(2:4, 6:8));
        end
    end
    
    methods (TestClassSetup)
        function setupTestDir(testCase)
            % Create test directory
            mkdir('test_array');
            testCase.addTeardown(@() rmdir('test_array', 's'));
        end
    end
end
