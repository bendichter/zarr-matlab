function tests = test_gzip_codec
% TEST_GZIP_CODEC Test suite for zarr.codecs.GzipCodec
    tests = functiontests(localfunctions);
end

function test_gzip_basic(testCase)
    % Test basic Gzip compression/decompression
    
    % Create codec with default settings
    codec = zarr.codecs.GzipCodec();
    
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

function test_gzip_empty(testCase)
    % Test Gzip with empty data
    
    codec = zarr.codecs.GzipCodec();
    
    % Test with empty array
    original = uint8(zeros(0,0));
    
    % Compress
    compressed = codec.encode(original);
    
    % Decompress
    decompressed = codec.decode(compressed);
    
    % Verify roundtrip
    testCase.verifyEqual(decompressed, original);
end

function test_gzip_compression_levels(testCase)
    % Test different compression levels
    
    % Create test data
    data = uint8(repmat([1:100], 1, 100));  % Repetitive data for better compression
    
    % Test different levels
    levels = [1 3 5 7 9];  % Test range of compression levels
    compressed_sizes = zeros(size(levels));
    
    for i = 1:numel(levels)
        codec = zarr.codecs.GzipCodec(levels(i));
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

function test_gzip_errors(testCase)
    % Test error conditions
    
    % Test invalid compression level
    testCase.verifyError(@() zarr.codecs.GzipCodec(-1), ...
        'zarr:InvalidCompressionLevel');
    testCase.verifyError(@() zarr.codecs.GzipCodec(10), ...
        'zarr:InvalidCompressionLevel');
    
    % Test invalid input type
    codec = zarr.codecs.GzipCodec();
    testCase.verifyError(@() codec.encode(single([1 2 3])), ...
        'zarr:InvalidInput');
end

function test_gzip_large_data(testCase)
    % Test with larger data to ensure it handles memory properly
    
    codec = zarr.codecs.GzipCodec();
    
    % Create large data (10MB)
    original = uint8(randi([0 255], 1, 10*1024*1024));
    
    % Compress
    compressed = codec.encode(original);
    
    % Decompress
    decompressed = codec.decode(compressed);
    
    % Verify roundtrip
    testCase.verifyEqual(decompressed, original);
end

function test_gzip_random_data(testCase)
    % Test with random data of different sizes
    
    codec = zarr.codecs.GzipCodec();
    
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
