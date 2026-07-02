classdef TestVlen < matlab.unittest.TestCase
    %Variable-length string / bytes dtypes.

    properties
        store
    end

    methods (TestMethodSetup)
        function freshStore(tc)
            tc.store = zarr.stores.MemoryStore();
        end
    end

    methods (Test)
        function stringRoundTrip(tc)
            z = zarr.create(tc.store, [3 4], "string", ChunkShape=[2 2], ...
                Codecs={zarr.codecs.GzipCodec(5)}, FillValue="?");
            d = reshape("s" + string(1:12), [3 4]);
            z(:, :) = d;
            tc.verifyEqual(z(:, :), d);
            tc.verifyEqual(z(2, 3), d(2, 3));
        end

        function unicodeAndEmpty(tc)
            z = zarr.create(tc.store, 4, "string", ChunkShape=4);
            greek = string(native2unicode(uint8([206 177 206 178 206 179]), 'UTF-8'));
            d = ["plain"; greek; ""; "x"];
            z(:) = d;
            tc.verifyEqual(z(:), d);
            % byte framing matches numcodecs vlen-utf8 exactly
            [bytes, ~] = tc.store.get("c/0");
            tc.verifyEqual(typecast(bytes(1:4), 'uint32'), uint32(4));
            tc.verifyEqual(typecast(bytes(5:8), 'uint32'), uint32(5));  % "plain"
        end

        function stringFillValue(tc)
            z = zarr.create(tc.store, [4 4], "string", ChunkShape=[2 2], FillValue="NA");
            z(1:2, 1:2) = ["a" "b"; "c" "d"];
            out = z(:, :);
            tc.verifyEqual(out(3, 3), "NA");
        end

        function bytesRoundTrip(tc)
            z = zarr.create(tc.store, 5, "bytes", ChunkShape=2);
            d = {uint8([1 2]); uint8.empty(1, 0); uint8(255); uint8([9 8 7]); uint8(0)};
            z(:) = d;
            out = z(:);
            tc.verifyEqual(out, d);
        end

        function shardedStrings(tc)
            z = zarr.create(tc.store, [4 4], "string", ChunkShape=[2 2], ShardShape=[4 4]);
            d = reshape(string(1:16), [4 4]);
            z(:, :) = d;
            tc.verifyEqual(z(2:3, 2:3), d(2:3, 2:3));
        end

        function bytesCodecRejectsVlen(tc)
            tc.verifyError(@() zarr.create(tc.store, 4, "string", ...
                Codecs={zarr.codecs.BytesCodec()}, Path="bad").write(["a"; "b"; "c"; "d"]), ...
                "zarr:InvalidCodecs");
        end

        function metadataUsesVlenCodec(tc)
            z = zarr.create(tc.store, 4, "string", Path="s");
            tc.verifySubstring(char(z.meta.toJsonText()), '"vlen-utf8"');
            z2 = zarr.create(tc.store, 4, "bytes", Path="b");
            tc.verifySubstring(char(z2.meta.toJsonText()), '"vlen-bytes"');
            tc.verifySubstring(char(z2.meta.toJsonText()), '"variable_length_bytes"');
        end
    end
end
