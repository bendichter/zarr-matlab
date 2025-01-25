function tests = test_codec
% TEST_CODEC Test suite for zarr.codecs.BloscCodec
    tests = functiontests(localfunctions);
end

function test_blosc_basic(testCase)
    % Test basic Blosc compression/decompression
    
    % Create codec with default settings
    codec = zarr.codecs.BloscCodec();
    
    % Test with highly compressible data (repeated pattern)
    original = uint8(repmat([1:10], 1, 100));
    
    % Compress
    compressed = codec.encode(original);
    
    % Verify compression actually happened
    testCase.verifyTrue(numel(compressed) < numel(original));
    
    % Decompress
    decompressed = codec.decode(compressed);
    
    % Verify roundtrip
    testCase.verifyEqual(decompressed, original);
end

function test_blosc_empty(testCase)
    % Test Blosc with empty data
    
    codec = zarr.codecs.BloscCodec();
    
    % Test with empty array
    original = uint8(zeros(0,0));
    
    % Compress
    compressed = codec.encode(original);
    
    % Decompress
    decompressed = codec.decode(compressed);
    
    % Verify roundtrip
    testCase.verifyEqual(decompressed, original);
end

function test_blosc_compression_levels(testCase)
    % Test different compression levels
    
    % Create test data
    data = uint8(repmat([1:100], 1, 100));  % Repetitive data for better compression
    
    % Test different levels
    levels = [1 3 5 7 9];  % Test range of compression levels
    compressed_sizes = zeros(size(levels));
    
    for i = 1:numel(levels)
        codec = zarr.codecs.BloscCodec('clevel', levels(i));
        compressed = codec.encode(data);
        compressed_sizes(i) = numel(compressed);
        
        % Verify roundtrip
        decompressed = codec.decode(compressed);
        testCase.verifyEqual(decompressed, data);
    end
    
    % Verify higher levels generally give better compression
    % Note: This might not always be true for all data, but should be for our test data
    testCase.verifyTrue(all(diff(compressed_sizes) <= 0));
end

function test_blosc_compressors(testCase)
    % Test different compression algorithms
    
    % Create test data
    data = uint8(repmat([1:100], 1, 100));
    
    % Test each supported compressor
    compressors = {'lz4', 'zlib', 'zstd'};
    
    for i = 1:numel(compressors)
        codec = zarr.codecs.BloscCodec('cname', compressors{i});
        compressed = codec.encode(data);
        decompressed = codec.decode(compressed);
        testCase.verifyEqual(decompressed, data);
    end
end

function test_blosc_shuffle(testCase)
    % Test shuffle filter options
    
    % Create test data
    data = uint8(repmat([1:100], 1, 100));
    
    % Test with and without shuffle
    codec_shuffle = zarr.codecs.BloscCodec('shuffle', true);
    codec_no_shuffle = zarr.codecs.BloscCodec('shuffle', false);
    
    % Compress and verify roundtrip with shuffle
    compressed = codec_shuffle.encode(data);
    decompressed = codec_shuffle.decode(compressed);
    testCase.verifyEqual(decompressed, data);
    
    % Compress and verify roundtrip without shuffle
    compressed = codec_no_shuffle.encode(data);
    decompressed = codec_no_shuffle.decode(compressed);
    testCase.verifyEqual(decompressed, data);
end

function test_blosc_config(testCase)
    % Test codec configuration
    
    % Create codec with specific settings
    codec = zarr.codecs.BloscCodec('cname', 'zstd', 'clevel', 5, ...
        'shuffle', true, 'blocksize', 0);
    
    % Get config
    config = codec.get_config();
    
    % Verify config
    testCase.verifyEqual(config.id, 'blosc');
    testCase.verifyEqual(config.cname, 'zstd');
    testCase.verifyEqual(config.clevel, 5);
    testCase.verifyTrue(config.shuffle);
    testCase.verifyEqual(config.blocksize, 0);
    
    % Create new codec from config
    codec2 = zarr.codecs.BloscCodec.from_config(config);
    
    % Verify codecs are equal
    testCase.verifyTrue(codec == codec2);
end

function test_blosc_errors(testCase)
    % Test error conditions
    
    % Test invalid compression level
    testCase.verifyError(@() zarr.codecs.BloscCodec('clevel', -1), ...
        'MATLAB:notGreaterEqual');
    testCase.verifyError(@() zarr.codecs.BloscCodec('clevel', 10), ...
        'MATLAB:notLessEqual');
    
    % Test invalid compressor name
    testCase.verifyError(@() zarr.codecs.BloscCodec('cname', 'invalid'), ...
        'MATLAB:unrecognizedStringChoice');
    
    % Test invalid input type
    codec = zarr.codecs.BloscCodec();
    testCase.verifyError(@() codec.encode(single([1 2 3])), ...
        'MATLAB:invalidType');
    
    % Test invalid config
    invalid_config = struct('id', 'invalid');
    testCase.verifyError(@() zarr.codecs.BloscCodec.from_config(invalid_config), ...
        'Zarr:Error');
end

function test_blosc_equality(testCase)
    % Test codec equality comparison
    
    % Create codecs with same settings
    codec1a = zarr.codecs.BloscCodec('cname', 'zstd', 'clevel', 5);
    codec1b = zarr.codecs.BloscCodec('cname', 'zstd', 'clevel', 5);
    
    % Create codec with different settings
    codec2 = zarr.codecs.BloscCodec('cname', 'lz4', 'clevel', 5);
    codec3 = zarr.codecs.BloscCodec('cname', 'zstd', 'clevel', 7);
    
    % Test equality
    testCase.verifyTrue(codec1a == codec1b);
    testCase.verifyFalse(codec1a == codec2);
    testCase.verifyFalse(codec1a == codec3);
end

function test_blosc_large_data(testCase)
    % Test with larger data to ensure it handles memory properly
    
    codec = zarr.codecs.BloscCodec();
    
    % Create large data (10MB)
    original = uint8(randi([0 255], 1, 10*1024*1024));
    
    % Compress
    compressed = codec.encode(original);
    
    % Decompress
    decompressed = codec.decode(compressed);
    
    % Verify roundtrip
    testCase.verifyEqual(decompressed, original);
end

function test_blosc_random_data(testCase)
    % Test with random data of different sizes
    
    codec = zarr.codecs.BloscCodec();
    
    % Test different sizes
    sizes = [100 1000 10000];
    
    for size = sizes
        % Create random data
        original = uint8(randi([0 255], 1, size));
        
        % Compress
        compressed = codec.encode(original);
        
        % Decompress
        decompressed = codec.decode(compressed);
        
        % Verify roundtrip
        testCase.verifyEqual(decompressed, original);
    end
end
