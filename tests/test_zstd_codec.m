function tests = test_zstd_codec
% TEST_ZSTD_CODEC Test suite for zarr.codecs.ZstdCodec
    tests = functiontests(localfunctions);
end

function test_zstd_basic(testCase)
    % Test basic Zstd compression/decompression
    
    % Create codec with default settings
    codec = zarr.codecs.ZstdCodec();
    
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

function test_zstd_empty(testCase)
    % Test Zstd with empty data
    
    codec = zarr.codecs.ZstdCodec();
    
    % Test with empty array
    original = uint8(zeros(0,0));
    
    % Compress
    compressed = codec.encode(original);
    
    % Decompress
    decompressed = codec.decode(compressed);
    
    % Verify roundtrip
    testCase.verifyEqual(decompressed, original);
end

function test_zstd_compression_levels(testCase)
    % Test different compression levels
    
    % Create test data
    data = uint8(repmat([1:100], 1, 100));  % Repetitive data for better compression
    
    % Test different levels
    levels = [-5 1 3 10 22];  % Test range of compression levels
    compressed_sizes = zeros(size(levels));
    
    for i = 1:numel(levels)
        codec = zarr.codecs.ZstdCodec('level', levels(i));
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

function test_zstd_checksum(testCase)
    % Test checksum functionality
    
    % Create test data
    data = uint8(repmat([1:100], 1, 100));
    
    % Test with and without checksum
    codec_checksum = zarr.codecs.ZstdCodec('checksum', true);
    codec_no_checksum = zarr.codecs.ZstdCodec('checksum', false);
    
    % Compress and verify roundtrip with checksum
    compressed = codec_checksum.encode(data);
    decompressed = codec_checksum.decode(compressed);
    testCase.verifyEqual(decompressed, data);
    
    % Compress and verify roundtrip without checksum
    compressed = codec_no_checksum.encode(data);
    decompressed = codec_no_checksum.decode(compressed);
    testCase.verifyEqual(decompressed, data);
end

function test_zstd_config(testCase)
    % Test codec configuration
    
    % Create codec with specific settings
    codec = zarr.codecs.ZstdCodec('level', 5, 'checksum', true);
    
    % Get config
    config = codec.get_config();
    
    % Verify config
    testCase.verifyEqual(config.id, 'zstd');
    testCase.verifyEqual(config.level, 5);
    testCase.verifyTrue(config.checksum);
    
    % Create new codec from config
    codec2 = zarr.codecs.ZstdCodec.from_config(config);
    
    % Verify codecs are equal
    testCase.verifyTrue(codec == codec2);
end

function test_zstd_errors(testCase)
    % Test error conditions
    
    % Test invalid input type
    codec = zarr.codecs.ZstdCodec();
    testCase.verifyError(@() codec.encode(single([1 2 3])), ...
        'zarr:InvalidInput');
    
    % Test invalid config
    invalid_config = struct('id', 'invalid');
    testCase.verifyError(@() zarr.codecs.ZstdCodec.from_config(invalid_config), ...
        'zarr:InvalidCodecConfig');
end

function test_zstd_equality(testCase)
    % Test codec equality comparison
    
    % Create codecs with same settings
    codec1a = zarr.codecs.ZstdCodec('level', 5, 'checksum', true);
    codec1b = zarr.codecs.ZstdCodec('level', 5, 'checksum', true);
    
    % Create codec with different settings
    codec2 = zarr.codecs.ZstdCodec('level', 3, 'checksum', true);
    codec3 = zarr.codecs.ZstdCodec('level', 5, 'checksum', false);
    
    % Test equality
    testCase.verifyTrue(codec1a == codec1b);
    testCase.verifyFalse(codec1a == codec2);
    testCase.verifyFalse(codec1a == codec3);
end

function test_zstd_large_data(testCase)
    % Test with larger data to ensure it handles memory properly
    
    codec = zarr.codecs.ZstdCodec();
    
    % Create large data (10MB)
    original = uint8(randi([0 255], 1, 10*1024*1024));
    
    % Compress
    compressed = codec.encode(original);
    
    % Decompress
    decompressed = codec.decode(compressed);
    
    % Verify roundtrip
    testCase.verifyEqual(decompressed, original);
end

function test_zstd_random_data(testCase)
    % Test with random data of different sizes
    
    codec = zarr.codecs.ZstdCodec();
    
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
