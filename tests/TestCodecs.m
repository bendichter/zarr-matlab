classdef TestCodecs < matlab.unittest.TestCase
    %Codec round trips and error handling, straight through the Pipeline.

    properties (TestParameter)
        dtype = {"bool", "int8", "int16", "int32", "int64", "uint8", "uint16", ...
                 "uint32", "uint64", "float16", "float32", "float64", ...
                 "complex64", "complex128"};
        endian = {"little", "big"};
    end

    methods (Static)
        function A = sample(dtype, shape)
            A = interop_pattern(shape, dtype);
        end

        function p = makePipeline(codecs, dtype, shape)
            info = zarr.internal.dtype_info(dtype);
            p = zarr.codecs.Pipeline(codecs, info, shape);
        end
    end

    methods (Test)
        function bytesAllDtypes(tc, dtype, endian)
            shape = [3 5];
            p = tc.makePipeline({zarr.codecs.BytesCodec(endian)}, dtype, shape);
            A = tc.sample(dtype, shape);
            tc.verifyEqual(p.decode(p.encode(A)), A);
        end

        function bytesLengthValidation(tc)
            p = tc.makePipeline({zarr.codecs.BytesCodec()}, "float64", [2 2]);
            tc.verifyError(@() p.decode(zeros(1, 31, 'uint8')), "zarr:CodecError");
        end

        function gzipLevels(tc)
            for level = [0 1 5 9]
                p = tc.makePipeline({zarr.codecs.BytesCodec(), ...
                    zarr.codecs.GzipCodec(level)}, "float64", 100);
                A = tc.sample("float64", 100);
                tc.verifyEqual(p.decode(p.encode(A)), A);
            end
        end

        function crc32cDetectsCorruption(tc)
            p = tc.makePipeline({zarr.codecs.BytesCodec(), ...
                zarr.codecs.Crc32cCodec()}, "int32", 10);
            bytes = p.encode(tc.sample("int32", 10));
            bytes(3) = bytes(3) + 1;
            tc.verifyError(@() p.decode(bytes), "zarr:ChecksumError");
        end

        function transpose3d(tc)
            shape = [3 4 5];
            p = tc.makePipeline({zarr.codecs.TransposeCodec([2 0 1]), ...
                zarr.codecs.BytesCodec()}, "float64", shape);
            A = tc.sample("float64", shape);
            tc.verifyEqual(p.decode(p.encode(A)), A);
        end

        function transposeValidation(tc)
            tc.verifyError(@() zarr.codecs.TransposeCodec([0 2]), "zarr:CodecError");
        end

        function zstdRoundTrip(tc)
            tc.assumeTrue(~isempty(which('zarr.internal.zstd_mex')), 'MEX not built');
            for args = {{}, {19, true}, {-5}}
                p = tc.makePipeline({zarr.codecs.BytesCodec(), ...
                    zarr.codecs.ZstdCodec(args{1}{:})}, "float64", [20 10]);
                A = tc.sample("float64", [20 10]);
                tc.verifyEqual(p.decode(p.encode(A)), A);
            end
        end

        function bloscVariants(tc)
            tc.assumeTrue(~isempty(which('zarr.internal.blosc_mex')), 'MEX not built');
            for cname = ["lz4", "lz4hc", "blosclz", "zstd", "zlib"]
                for shuffle = ["noshuffle", "shuffle", "bitshuffle"]
                    codec = zarr.codecs.BloscCodec(cname=cname, clevel=5, ...
                        shuffle=shuffle, typesize=8);
                    p = tc.makePipeline({zarr.codecs.BytesCodec(), codec}, ...
                        "float64", [10 10]);
                    A = tc.sample("float64", [10 10]);
                    tc.verifyEqual(p.decode(p.encode(A)), A, ...
                        sprintf('%s/%s', cname, shuffle));
                end
            end
        end

        function shardingPipelineRoundTrip(tc)
            info = zarr.internal.dtype_info("float64");
            sh = zarr.codecs.ShardingCodec([2 3], ...
                Codecs={zarr.codecs.GzipCodec(5)});
            for loc = ["start", "end"]
                sh.indexLocation = loc;
                p = zarr.codecs.Pipeline({sh}, info, [6 6], NaN);
                A = tc.sample("float64", [6 6]);
                tc.verifyEqual(p.decode(p.encode(A)), A);
            end
        end

        function shardingRejectsNonDividingShape(tc)
            info = zarr.internal.dtype_info("float64");
            sh = zarr.codecs.ShardingCodec([4 4]);
            tc.verifyError(@() zarr.codecs.Pipeline({sh}, info, [6 6], 0), ...
                "zarr:InvalidMetadata");
        end

        function pipelineOrderValidation(tc)
            info = zarr.internal.dtype_info("float64");
            % no array->bytes codec
            tc.verifyError(@() zarr.codecs.Pipeline({zarr.codecs.GzipCodec(5)}, ...
                info, [2 2]), "zarr:InvalidMetadata");
            % bytes->bytes before array->bytes
            tc.verifyError(@() zarr.codecs.Pipeline({zarr.codecs.GzipCodec(5), ...
                zarr.codecs.BytesCodec()}, info, [2 2]), "zarr:InvalidMetadata");
        end
    end
end
