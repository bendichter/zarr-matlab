classdef test_delta_codec < matlab.unittest.TestCase
    methods(Test)
        function test_basic_encoding(testCase)
            codec = zarr.codecs.DeltaCodec('int32');
            data = int32([5 7 9 11]);
            encoded = codec.encode(data);
            testCase.verifyEqual(encoded, int32([5 2 2 2]));
            
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, data);
        end
        
        function test_dtype_handling(testCase)
            % Test different data types
            types = {'uint8', 'int16', 'single', 'double'};
            for t = types
                codec = zarr.codecs.DeltaCodec(t{1});
                data = cast([10 15 17 20], t{1});
                
                encoded = codec.encode(data);
                decoded = codec.decode(encoded);
                
                testCase.verifyClass(encoded, t{1});
                testCase.verifyClass(decoded, t{1});
                testCase.verifyEqual(decoded, data);
            end
        end
        
        function test_empty_array(testCase)
            codec = zarr.codecs.DeltaCodec('double');
            data = double.empty(0,5);
            
            encoded = codec.encode(data);
            testCase.verifyEmpty(encoded);
            
            decoded = codec.decode(encoded);
            testCase.verifyEmpty(decoded);
        end
        
        function test_python_compatibility(testCase)
            % Test with data generated by Python numcodecs
            pyfile = fullfile(fileparts(mfilename('fullpath')), 'data/delta/test_data.bin');
            
            % Read Python-generated encoded data
            fid = fopen(pyfile, 'rb');
            if fid == -1
                error('Failed to open test data file: %s', pyfile);
            end
            cleanup = onCleanup(@() fclose(fid));
            
            encoded = fread(fid, Inf, 'int32');
            
            codec = zarr.codecs.DeltaCodec('int32');
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, int32([100 150 175 200 225]'));
        end

        function test_multidimensional_array(testCase)
            % Test 2D array
            codec = zarr.codecs.DeltaCodec('int32');
            data = int32([1 2 3; 4 5 6; 7 8 9]);
            
            encoded = codec.encode(data);
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, data);
            
            % Test 3D array
            data3d = int32(reshape(1:27, [3 3 3]));
            encoded3d = codec.encode(data3d);
            decoded3d = codec.decode(encoded3d);
            testCase.verifyEqual(decoded3d, data3d);
        end
        
        function test_array_shapes(testCase)
            codec = zarr.codecs.DeltaCodec('int32');
            
            % Row vector
            row_data = int32([1 2 3 4]);
            encoded = codec.encode(row_data);
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, row_data);
            
            % Column vector
            col_data = int32([1; 2; 3; 4]);
            encoded = codec.encode(col_data);
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, col_data);
        end
        
        function test_negative_numbers(testCase)
            codec = zarr.codecs.DeltaCodec('int32');
            data = int32([-5 -2 1 4]);
            
            encoded = codec.encode(data);
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, data);
        end
        
        function test_overflow(testCase)
            % Test int8 overflow
            codec = zarr.codecs.DeltaCodec('int8');
            data = int8([120 -120 100]); % Should cause overflow in differences
            
            encoded = codec.encode(data);
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, data);
            
            % Test uint8 overflow
            codec = zarr.codecs.DeltaCodec('uint8');
            data = uint8([250 5 200]); % Should cause overflow in differences
            
            encoded = codec.encode(data);
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, data);
        end
    end
end
