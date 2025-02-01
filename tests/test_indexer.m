classdef test_indexer < matlab.unittest.TestCase
    % TEST_INDEXER Unit tests for Indexer class
    
    methods (Test)
        function test_basic_indexing(testCase)
            % Test basic indexing operations
            shape = [10 10];
            chunks = [5 5];
            dtype = 'double';
            grid = zarr.core.ChunkGrid(shape, chunks, '/');
            pipeline = zarr.core.CodecPipeline([], {});
            store = zarr.storage.FileStore('test_indexer');
            path = '';
            
            indexer = zarr.core.Indexer(shape, chunks, dtype, grid, pipeline, store, path);
            
            % Test single point indexing
            subs = {1, 1};
            indices = indexer.parse_subscripts(subs);
            [chunk_coords, chunk_idx] = grid.get_chunk_coords(indices);
            testCase.verifyEqual(chunk_coords, [1; 1]);
            testCase.verifyEqual(chunk_idx, 1);
            
            % Test multiple points in same chunk
            subs = {[1 2 3], [1 2 3]};
            indices = indexer.parse_subscripts(subs);
            [chunk_coords, chunk_idx] = grid.get_chunk_coords(indices);
            testCase.verifyEqual(chunk_coords, [1; 1]);
            testCase.verifyEqual(chunk_idx, ones(1,9));
            
            % Test points across chunks
            subs = {[3 4 5 6], [3 4 5 6]};
            indices = indexer.parse_subscripts(subs);
            [chunk_coords, chunk_idx] = grid.get_chunk_coords(indices);
            testCase.verifyEqual(chunk_coords, [1 1 2 2; 1 2 1 2]);
            testCase.verifyEqual(chunk_idx, [1 1 1 3 1 1 1 3 1 1 1 3 2 2 2 4]);
        end
        
        function test_chunk_retrieval(testCase)
            % Test chunk retrieval operations
            shape = [10 10];
            chunks = [5 5];
            dtype = 'double';
            grid = zarr.core.ChunkGrid(shape, chunks, '/');
            pipeline = zarr.core.CodecPipeline([], {});
            store = zarr.storage.FileStore('test_indexer');
            path = '';
            
            indexer = zarr.core.Indexer(shape, chunks, dtype, grid, pipeline, store, path);
            
            % Test getting non-existent chunk (should return zeros)
            chunk = indexer.get_chunk([1 1]);
            testCase.verifyEqual(size(chunk), [5 5]);
            testCase.verifyEqual(chunk, zeros(5, 5));
            
            % Test chunk shape at edge
            chunk = indexer.get_chunk([2 2]);
            testCase.verifyEqual(size(chunk), [5 5]);
        end
        
        function test_local_indices(testCase)
            % Test local index calculation
            shape = [10 10];
            chunks = [5 5];
            grid = zarr.core.ChunkGrid(shape, chunks, '/');
            
            % Test single point in first chunk
            global_indices = {1, 1};
            chunk_coords = [1 1];
            local = grid.get_local_indices(global_indices, chunk_coords);
            testCase.verifyEqual(local, {1, 1});
            
            % Test multiple points in first chunk
            global_indices = {[1 2 3], [1 2 3]};
            chunk_coords = [1 1];
            local = grid.get_local_indices(global_indices, chunk_coords);
            testCase.verifyEqual(local{1}, [1; 2; 3]);
            testCase.verifyEqual(local{2}, [1; 2; 3]);
            
            % Test points in second chunk
            global_indices = {[6 7 8], [6 7 8]};
            chunk_coords = [2 2];
            local = grid.get_local_indices(global_indices, chunk_coords);
            testCase.verifyEqual(local{1}, [1; 2; 3]);
            testCase.verifyEqual(local{2}, [1; 2; 3]);
        end
    end
    
    methods (TestClassSetup)
        function setupTestDir(testCase)
            % Create test directory
            mkdir('test_indexer');
            testCase.addTeardown(@() rmdir('test_indexer', 's'));
        end
    end
end
