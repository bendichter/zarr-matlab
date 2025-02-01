classdef test_chunk_grid < matlab.unittest.TestCase
    % TEST_CHUNK_GRID Unit tests for ChunkGrid class
    
    methods (Test)
        function test_get_chunk_coords(testCase)
            % Test chunk coordinate calculation
            shape = [10 10];
            chunks = [5 5];
            grid = zarr.core.ChunkGrid(shape, chunks, '/');
            
            % Test single point
            indices = {1, 1};
            [coords, idx] = grid.get_chunk_coords(indices);
            testCase.verifyEqual(coords, [1; 1]);
            testCase.verifyEqual(idx, 1);
            
            % Test multiple points in same chunk
            indices = {[1 2 3], [1 2 3]};
            [coords, idx] = grid.get_chunk_coords(indices);
            testCase.verifyEqual(coords, [1; 1]);
            testCase.verifyEqual(idx, ones(1,9));
            
            % Test points across chunks
            indices = {[3 4 5 6], [3 4 5 6]};
            [coords, idx] = grid.get_chunk_coords(indices);
            testCase.verifyEqual(coords, [1 1 2 2; 1 2 1 2]);
            testCase.verifyEqual(idx, [1 1 1 3 1 1 1 3 1 1 1 3 2 2 2 4]);
        end
        
        function test_get_local_indices(testCase)
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
            testCase.verifyEqual(local, {[1 2 3]', [1 2 3]'});
            
            % Test points in second chunk
            global_indices = {[6 7 8], [6 7 8]};
            chunk_coords = [2 2];
            local = grid.get_local_indices(global_indices, chunk_coords);
            testCase.verifyEqual(local, {[1 2 3]', [1 2 3]'});
        end
        
        function test_get_chunk_shape(testCase)
            % Test chunk shape calculation
            shape = [10 10];
            chunks = [5 5];
            grid = zarr.core.ChunkGrid(shape, chunks, '/');
            
            % Test regular chunk
            coords = [1 1];
            chunk_shape = grid.get_chunk_shape(coords);
            testCase.verifyEqual(chunk_shape, [5 5]);
            
            % Test edge chunk
            coords = [2 2];
            chunk_shape = grid.get_chunk_shape(coords);
            testCase.verifyEqual(chunk_shape, [5 5]);
            
            % Test with non-uniform chunks
            shape = [12 12];
            chunks = [5 5];
            grid = zarr.core.ChunkGrid(shape, chunks, '/');
            
            coords = [3 3];
            chunk_shape = grid.get_chunk_shape(coords);
            testCase.verifyEqual(chunk_shape, [2 2]);
        end
        
        function test_coords_to_key(testCase)
            % Test chunk key generation
            shape = [10 10];
            chunks = [5 5];
            
            % Test with dot separator
            grid = zarr.core.ChunkGrid(shape, chunks, '.');
            key = grid.coords_to_key([1 1], '');
            testCase.verifyEqual(key, '/1.1');
            
            % Test with slash separator
            grid = zarr.core.ChunkGrid(shape, chunks, '/');
            key = grid.coords_to_key([1 1], '');
            testCase.verifyEqual(key, '/1/1');
        end
        
        function test_key_to_coords(testCase)
            % Test chunk coordinate parsing
            shape = [10 10];
            chunks = [5 5];
            
            % Test with dot separator
            grid = zarr.core.ChunkGrid(shape, chunks, '.');
            coords = grid.key_to_coords('/1.1', '');
            testCase.verifyEqual(coords, [1 1]);
            
            % Test with slash separator
            grid = zarr.core.ChunkGrid(shape, chunks, '/');
            coords = grid.key_to_coords('/1/1', '');
            testCase.verifyEqual(coords, [1 1]);
        end
    end
end
