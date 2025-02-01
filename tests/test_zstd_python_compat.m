function tests = test_zstd_python_compat
% TEST_ZSTD_PYTHON_COMPAT Test compatibility with Python's Zstd codec implementation
    tests = functiontests(localfunctions);
end

function test_zstd_default_settings(testCase)
    % Test compatibility with Python's default Zstd settings
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Create store
    store = zarr.storage.FileStore(temp_dir);
    
    % Create array with default Zstd compression
    array = zarr.create(store, [100 100], 'double', ...
        'compressor', zarr.codecs.ZstdCodec());  % Use defaults
    
    % Write test data
    data = rand(100);
    array(:,:) = data;
    
    % Verify metadata format and content
    meta_str = char(store.get('.zarray'));
    meta = jsondecode(meta_str);
    
    % Get codec from metadata
    codec = meta.compressor;
    
    % Verify Zstd settings match Python defaults
    testCase.verifyEqual(codec.id, 'zstd');
    testCase.verifyEqual(codec.level, 0);  % Python's default level
    testCase.verifyFalse(codec.checksum);  % Python's default checksum setting
    
    % Verify data can be read back correctly
    retrieved = array(:,:);
    testCase.verifyEqual(retrieved, data);
end

function test_zstd_compression_levels(testCase)
    % Test compatibility with different compression levels
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Test different compression levels
    levels = [-131072 -22 0 3 22];  % Test range of compression levels
    
    for i = 1:numel(levels)
        level = levels(i);
        
        % Create store for this level
        store = zarr.storage.FileStore(fullfile(temp_dir, sprintf('level_%d', level)));
        
        % Create array with specific compression level
        array = zarr.create(store, [100 100], 'double', ...
            'compressor', zarr.codecs.ZstdCodec('level', level));
        
        % Write test data
        data = rand(100);
        array(:,:) = data;
        
        % Verify metadata
        meta_str = char(store.get('.zarray'));
        meta = jsondecode(meta_str);
        
        % Get codec from metadata
        codec = meta.compressor;
        
        % Verify compression level
        testCase.verifyEqual(codec.level, level);
        
        % Verify data roundtrip
        retrieved = array(:,:);
        testCase.verifyEqual(retrieved, data);
    end
end

function test_zstd_checksum(testCase)
    % Test compatibility with checksum flag
    
    % Create temporary directory for testing
    temp_dir = tempname;
    mkdir(temp_dir);
    cleanup = onCleanup(@() rmdir(temp_dir, 's'));
    
    % Test with and without checksum
    checksum_values = [true false];
    
    for i = 1:numel(checksum_values)
        use_checksum = checksum_values(i);
        
        % Create store
        store = zarr.storage.FileStore(fullfile(temp_dir, sprintf('checksum_%d', use_checksum)));
        
        % Create array with specific checksum setting
        array = zarr.create(store, [100 100], 'double', ...
            'compressor', zarr.codecs.ZstdCodec('checksum', use_checksum));
        
        % Write test data
        data = rand(100);
        array(:,:) = data;
        
        % Verify metadata
        meta_str = char(store.get('.zarray'));
        meta = jsondecode(meta_str);
        
        % Get codec from metadata
        codec = meta.compressor;
        
        % Verify checksum setting
        testCase.verifyEqual(codec.checksum, use_checksum);
        
        % Verify data roundtrip
        retrieved = array(:,:);
        testCase.verifyEqual(retrieved, data);
    end
end

function test_zstd_dtype_compatibility(testCase)
    % Test Zstd compression with different data types
    
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
        array = zarr.create(store, [10 10], dtype, ...
            'compressor', zarr.codecs.ZstdCodec());
        
        % Write test data
        if startsWith(dtype, 'int') || startsWith(dtype, 'uint')
            data = cast(randi(100, [10 10]), dtype);
        else
            data = cast(rand(10, 10), dtype);
        end
        array(:,:) = data;
        
        % Verify data roundtrip
        retrieved = array(:,:);
        testCase.verifyEqual(retrieved, data);
    end
end
