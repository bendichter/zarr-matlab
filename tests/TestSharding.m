classdef TestSharding < matlab.unittest.TestCase
    %sharding_indexed: geometry, partial reads, fills, corruption, nesting.

    properties
        store
    end

    methods (TestMethodSetup)
        function freshStore(tc)
            tc.store = zarr.stores.MemoryStore();
        end
    end

    methods (Test)
        function roundTripBothIndexLocations(tc)
            d = reshape((1:120) * 0.5, [12 10]);
            for loc = ["start", "end"]
                z = zarr.create(tc.store, [12 10], "float64", ChunkShape=[3 5], ...
                    ShardShape=[6 10], IndexLocation=loc, Path="a_" + loc, ...
                    Codecs={zarr.codecs.GzipCodec(5), zarr.codecs.Crc32cCodec()});
                z(:, :) = d;
                tc.verifyEqual(z(:, :), d, loc);
                tc.verifyEqual(z(2:9, 3:10), d(2:9, 3:10), loc + " partial");
            end
        end

        function missingShardAndInnerChunkAreFill(tc)
            z = zarr.create(tc.store, [8 8], "float64", ChunkShape=[2 2], ...
                ShardShape=[4 4], FillValue=NaN);
            z(1:2, 1:2) = ones(2);
            out = z(:, :);
            tc.verifyEqual(out(1:2, 1:2), ones(2));
            tc.verifyTrue(all(isnan(out(5:8, :)), 'all'), 'missing shard');
            tc.verifyTrue(all(isnan(out(3:4, 3:4)), 'all'), 'missing inner chunk');
        end

        function readModifyWriteWithinShard(tc)
            z = zarr.create(tc.store, [8 8], "int32", ChunkShape=[2 2], ShardShape=[8 8]);
            d = reshape(int32(1:64), [8 8]);
            z(:, :) = d;
            z(3:4, 5:7) = int32(zeros(2, 3));
            d(3:4, 5:7) = int32(zeros(2, 3));
            tc.verifyEqual(z(:, :), d);
        end

        function nestedSharding(tc)
            z = zarr.create(tc.store, [8 8], "float64", ChunkShape=[4 4], ...
                ShardShape=[8 8], Codecs={zarr.codecs.ShardingCodec([2 2])});
            d = magic(8);
            z(:, :) = d;
            tc.verifyEqual(z(:, :), d);
        end

        function truncatedShardErrors(tc)
            z = zarr.create(tc.store, [4 4], "float64", ChunkShape=[2 2], ShardShape=[4 4]);
            z(:, :) = magic(4);
            [bytes, ~] = tc.store.get("c/0/0");
            tc.store.set("c/0/0", bytes(1:10));  % shorter than the index
            tc.verifyError(@() z(:, :), "zarr:CodecError");
        end

        function corruptIndexDetected(tc)
            z = zarr.create(tc.store, [4 4], "float64", ChunkShape=[2 2], ShardShape=[4 4]);
            z(:, :) = magic(4);
            [bytes, ~] = tc.store.get("c/0/0");
            bytes(end - 2) = bytes(end - 2) + 1;  % flip a bit in the crc32c'd index
            tc.store.set("c/0/0", bytes);
            tc.verifyError(@() z(:, :), "zarr:ChecksumError");
        end

        function shardShapeValidation(tc)
            tc.verifyError(@() zarr.create(tc.store, [8 8], "float64", ...
                ChunkShape=[3 3], ShardShape=[8 8], Path="bad"), ...
                "zarr:InvalidChunkShape");
        end

        function partialReadsUseRangedAccess(tc)
            % LocalStore path: partial read of one inner chunk must not read
            % the whole shard. Verified behaviorally: correct data + a probe
            % store that counts full get() calls.
            probe = CountingStore();
            z = zarr.create(probe, [8 8], "float64", ChunkShape=[2 2], ShardShape=[8 8]);
            z(:, :) = magic(8);
            probe.resetCounts();
            d = z(1:2, 1:2);  % one inner chunk
            tc.verifyEqual(d, subsref(magic(8), substruct('()', {1:2, 1:2})));
            tc.verifyEqual(probe.nFullGets, 0, 'no full-shard read on partial access');
            tc.verifyGreaterThan(probe.nPartialGets + probe.nSuffixGets, 0);
        end
    end
end
