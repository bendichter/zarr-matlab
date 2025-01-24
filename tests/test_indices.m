classdef test_indices < matlab.unittest.TestCase
    % TEST_INDICES Unit tests for index handling
    
    methods (Test)
        function test_index_format(testCase)
            % Test index formatting through the stack
            store = zarr.storage.FileStore('test_indices');
            shape = [10 10];
            chunks = [5 5];
            
            % Create array
            array = zarr.core.Array(store, '', shape, 'double', ...
                'chunks', chunks, 'compressor', []);
            
            % Test single point indexing
            subs = {1, 1};
            indices = array.indexer.parse_subscripts(subs);
            
            % Verify index format
            testCase.verifyEqual(numel(indices), 2);
            testCase.verifyEqual(indices{1}, 1);
            testCase.verifyEqual(indices{2}, 1);
            
            % Get chunk coordinates
            [chunk_coords, chunk_idx] = array.grid.get_chunk_coords(indices);
            
            % Print debug info
            fprintf('Indices: %s\n', mat2str([indices{:}]));
            fprintf('Chunk coords: %s\n', mat2str(chunk_coords));
            fprintf('Chunk idx: %s\n', mat2str(chunk_idx));
            
            % Test multiple points
            subs = {[1 2 3], [1 2 3]};
            indices = array.indexer.parse_subscripts(subs);
            
            % Verify index format
            testCase.verifyEqual(numel(indices), 2);
            testCase.verifyEqual(indices{1}, [1 2 3]);
            testCase.verifyEqual(indices{2}, [1 2 3]);
            
            % Get chunk coordinates
            [chunk_coords, chunk_idx] = array.grid.get_chunk_coords(indices);
            
            % Print debug info
            fprintf('Multiple indices: %s, %s\n', mat2str(indices{1}), mat2str(indices{2}));
            fprintf('Multiple chunk coords: %s\n', mat2str(chunk_coords));
            fprintf('Multiple chunk idx: %s\n', mat2str(chunk_idx));
        end
    end
    
    methods (TestClassSetup)
        function setupTestDir(testCase)
            % Create test directory
            mkdir('test_indices');
            testCase.addTeardown(@() rmdir('test_indices', 's'));
        end
    end
end
