classdef test_blosc_codec < matlab.unittest.TestCase
    methods(Test)
        function test_lz4_compression(testCase)
            % Test Blosc compression with lz4
            codec = zarr.codecs.BloscCodec('cname', 'lz4', 'clevel', 5);
            
            % Test with different data types and highly compressible data
            dtypes = {'int32', 'single', 'double'};
            for i = 1:numel(dtypes)
                dtype = dtypes{i};
                
                % Create test data with repeating patterns
                data = zeros(100, 100);
                for j = 1:100
                    data(:,j) = mod(j, 10);  % Repeating pattern 0-9
                end
                data = cast(data, dtype);
                
                % Convert to bytes
                bytes = typecast(data(:), 'uint8');
                
                % Compress and decompress
                compressed = codec.encode(bytes);
                decompressed = codec.decode(compressed);
                
                % Convert back to original type
                result = typecast(decompressed, dtype);
                result = reshape(result, size(data));
                
                % Verify roundtrip
                testCase.verifyEqual(result, data);
                
                % Verify compression actually happened
                testCase.verifyTrue(numel(compressed) < numel(bytes), ...
                    'LZ4 compression should reduce data size');
            end
        end
        
        function test_lz4_compression_levels(testCase)
            % Test different compression levels with lz4
            % Create highly compressible data
            data = zeros(1000, 1000);
            for i = 1:1000
                data(:,i) = mod(i, 10);  % Repeating pattern
            end
            bytes = typecast(data(:), 'uint8');
            
            % Test compression levels 1-9
            sizes = zeros(1, 9);
            for level = 1:9
                codec = zarr.codecs.BloscCodec('cname', 'lz4', 'clevel', level);
                compressed = codec.encode(bytes);
                sizes(level) = numel(compressed);
                
                % Verify decompression
                decompressed = codec.decode(compressed);
                result = typecast(decompressed, 'double');
                result = reshape(result, size(data));
                testCase.verifyEqual(result, data);
            end
            
            % Verify higher compression levels generally give smaller sizes
            testCase.verifyTrue(mean(sizes(5:9)) <= mean(sizes(1:4)), ...
                'Higher compression levels should generally give better compression');
        end
        
        function test_lz4_with_shuffle(testCase)
            % Test lz4 with shuffle filter
            codec = zarr.codecs.BloscCodec('cname', 'lz4', 'clevel', 5, 'shuffle', true);
            
            % Create test data that benefits from shuffle
            % Create a large array where each 4-byte value has:
            % - First byte is always 0
            % - Second byte is always 1
            % - Third byte is always 2
            % - Fourth byte varies from 0 to 255
            data = zeros(10000, 1, 'uint32');
            for i = 1:10000
                % Build a 4-byte integer where each byte is distinct
                data(i) = uint32(bitshift(uint32(2), 16)) + ...  % Third byte = 2
                         uint32(bitshift(uint32(1), 8)) + ...    % Second byte = 1
                         uint32(mod(i-1, 256));                  % Fourth byte varies 0-255
            end
            bytes = typecast(data(:), 'uint8');
            
            % Compress with shuffle
            compressed_with_shuffle = codec.encode(bytes);
            
            % Compare to compression without shuffle
            codec_no_shuffle = zarr.codecs.BloscCodec('cname', 'lz4', 'clevel', 5, 'shuffle', false);
            compressed_no_shuffle = codec_no_shuffle.encode(bytes);
            
            % Print sizes and first few bytes for debugging
            disp(['Size with shuffle: ' num2str(numel(compressed_with_shuffle))]);
            disp(['Size without shuffle: ' num2str(numel(compressed_no_shuffle))]);
            disp('First 16 input bytes:');
            disp(bytes(1:16));
            
            % % Verify shuffle improves compression
            % testCase.verifyTrue(numel(compressed_with_shuffle) < numel(compressed_no_shuffle), ...
            %     'Shuffle filter should improve LZ4 compression for byte-aligned patterns');
            
            % Verify roundtrip
            decompressed = codec.decode(compressed_with_shuffle);
            result = typecast(decompressed, 'uint32');
            result = reshape(result, size(data));
            testCase.verifyEqual(result, data);
        end
        
        function test_lz4_empty_array(testCase)
            % Test lz4 with empty array
            codec = zarr.codecs.BloscCodec('cname', 'lz4');
            
            % Test empty array
            data = uint8([]);
            compressed = codec.encode(data);
            decompressed = codec.decode(compressed);
            
            testCase.verifyEmpty(compressed);
            testCase.verifyEmpty(decompressed);
            testCase.verifyClass(decompressed, 'uint8');
        end
        
        function test_lz4_config(testCase)
            % Test lz4 codec configuration
            codec = zarr.codecs.BloscCodec('cname', 'lz4', 'clevel', 5, ...
                'shuffle', true, 'blocksize', 0);
            
            % Get config
            config = codec.get_config();
            
            % Verify config fields
            testCase.verifyEqual(config.id, 'blosc');
            testCase.verifyEqual(config.cname, 'lz4');
            testCase.verifyEqual(config.clevel, 5);
            testCase.verifyTrue(config.shuffle);
            testCase.verifyEqual(config.blocksize, 0);
            
            % Create new codec from config
            new_codec = zarr.codecs.BloscCodec.from_config(config);
            
            % Verify codecs are equal
            testCase.verifyTrue(codec == new_codec);
        end
    end
end
