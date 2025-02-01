classdef test_shuffle_codec < matlab.unittest.TestCase
    methods(Test)
        function test_zarr_roundtrip(testCase)
            % Test basic shuffle codec functionality with different dtypes
            dtypes = {'int32', 'uint16', 'single', 'double'};
            sizes = [4, 2, 4, 8];
            
            for i = 1:numel(dtypes)
                dtype = dtypes{i};
                element_size = sizes(i);
                
                % Create random test data
                data = rand(4, 4);
                if contains(dtype, 'int')
                    data = data * 100;
                end
                data = cast(data, dtype);
                
                % Create codec
                codec = zarr.codecs.ShuffleCodec(element_size);
                
                % Encode and decode
                encoded = codec.encode(data);
                decoded = codec.decode(encoded);
                
                % Verify roundtrip
                testCase.verifyEqual(decoded, data);
                testCase.verifyClass(decoded, dtype);
            end
        end
        
        function test_python_compat(testCase)
            % Test compatibility with Python-generated data
            zarr_path = fullfile(fileparts(mfilename('fullpath')), ...
                'data', 'shuffle_zarr');
            
            % Test each data type
            dtypes = {'int32', 'uint16', 'single', 'double'};
            sizes = [4, 2, 4, 8];
            
            for i = 1:numel(dtypes)
                dtype = dtypes{i};
                element_size = sizes(i);
                
                % Create store and get raw chunk data
                store = zarr.storage.DirectoryStore(zarr_path);
                chunk_key = [dtype '/1d/0'];  % First chunk of 1D array
                raw_data = store.get(chunk_key);
                
                % Create codec and verify roundtrip
                codec = zarr.codecs.ShuffleCodec(element_size);
                decoded = codec.decode(raw_data);
                encoded = codec.encode(decoded);
                testCase.verifyEqual(encoded, raw_data);
            end
        end
        
        function test_array_shapes(testCase)
            % Test different array shapes
            codec = zarr.codecs.ShuffleCodec(4);  % Use int32/float32 size
            
            % Test 1D array
            data1d = cast(1:10, 'single');
            encoded = codec.encode(data1d);
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, data1d);
            
            % Test 2D array
            data2d = cast(reshape(1:12, [3,4]), 'single');
            encoded = codec.encode(data2d);
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, data2d);
            
            % Test 3D array
            data3d = cast(reshape(1:24, [2,3,4]), 'single');
            encoded = codec.encode(data3d);
            decoded = codec.decode(encoded);
            testCase.verifyEqual(decoded, data3d);
        end
        
        function test_empty_array(testCase)
            % Test handling of empty arrays
            codec = zarr.codecs.ShuffleCodec(4);
            data = single([]);
            
            encoded = codec.encode(data);
            testCase.verifyEmpty(encoded);
            
            decoded = codec.decode(encoded);
            testCase.verifyEmpty(decoded);
        end
        
        function test_invalid_element_size(testCase)
            % Test validation of element size
            
            % Test zero element size
            testCase.verifyError(@() zarr.codecs.ShuffleCodec(0), ...
                'MATLAB:validation:IncompatibleSize');
            
            % Test negative element size
            testCase.verifyError(@() zarr.codecs.ShuffleCodec(-1), ...
                'MATLAB:validation:IncompatibleSize');
            
            % Test non-integer element size
            testCase.verifyError(@() zarr.codecs.ShuffleCodec(2.5), ...
                'MATLAB:validation:IncompatibleSize');
        end
    end
end
