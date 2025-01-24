classdef test_array_indexing_debug < matlab.unittest.TestCase
    % TEST_ARRAY_INDEXING_DEBUG Detailed tests for array indexing operations
    
    methods (Test)
        function test_single_point(testCase)
            % Test single point access
            store = zarr.storage.FileStore('test_array');
            array = zarr.core.Array(store, '', [10 10], 'double', ...
                'chunks', [5 5], 'compressor', []);
            
            % Test write
            array(1,1) = 42;
            fprintf('Single point write successful\n');
            
            % Test read
            value = array(1,1);
            testCase.verifyEqual(value, 42);
            fprintf('Single point read successful: %d\n', value);
        end
        
        function test_small_block(testCase)
            % Test 2x2 block access
            store = zarr.storage.FileStore('test_array');
            array = zarr.core.Array(store, '', [10 10], 'double', ...
                'chunks', [5 5], 'compressor', []);
            
            % Test write
            data = [1 2; 3 4];
            array(1:2, 1:2) = data;
            fprintf('Small block write successful\n');
            
            % Test read
            block = array(1:2, 1:2);
            testCase.verifyEqual(block, data);
            fprintf('Small block read successful:\n');
            disp(block);
        end
        
        function test_cross_chunk_block(testCase)
            % Test block across chunk boundaries
            store = zarr.storage.FileStore('test_array');
            array = zarr.core.Array(store, '', [10 10], 'double', ...
                'chunks', [5 5], 'compressor', []);
            
            % Test write
            data = reshape(1:4, [2 2]);
            array(4:5, 4:5) = data;
            fprintf('Cross-chunk block write successful\n');
            
            % Test read
            block = array(4:5, 4:5);
            testCase.verifyEqual(block, data);
            fprintf('Cross-chunk block read successful:\n');
            disp(block);
        end
        
        function test_row_slice(testCase)
            % Test row slice access
            store = zarr.storage.FileStore('test_array');
            array = zarr.core.Array(store, '', [10 10], 'double', ...
                'chunks', [5 5], 'compressor', []);
            
            % Fill with test data
            data = reshape(1:100, [10 10]);
            array(1:2, :) = data(1:2, :);
            fprintf('Row data write successful\n');
            
            % Test read
            row = array(1, :);
            testCase.verifyEqual(row, data(1, :));
            fprintf('Row slice read successful:\n');
            disp(row);
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
