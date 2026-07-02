classdef TestArray < matlab.unittest.TestCase
    %Array creation, indexing, region I/O, hierarchy, resize/append.

    properties
        store
    end

    methods (TestMethodSetup)
        function freshStore(tc)
            tc.store = zarr.stores.MemoryStore();
        end
    end

    methods (Test)
        function fullAndPartialRoundTrip(tc)
            z = zarr.create(tc.store, [10 13], "float64", ChunkShape=[4 5]);
            data = reshape(1:130, [10 13]);
            z(:, :) = data;
            tc.verifyEqual(z(:, :), data);
            tc.verifyEqual(z(2:7, 3:11), data(2:7, 3:11));
            tc.verifyEqual(z(end, end), data(end, end));
            tc.verifyEqual(z(:), data(:));
        end

        function fancyIndexing(tc)
            z = zarr.create(tc.store, [8 8], "int32", ChunkShape=[3 3]);
            d = reshape(int32(1:64), [8 8]);
            z(:, :) = d;
            tc.verifyEqual(z([1 5 8], [2 3]), d([1 5 8], [2 3]));
            tc.verifyEqual(z(logical([1 0 1 0 0 0 0 1]), :), ...
                d(logical([1 0 1 0 0 0 0 1]), :));
            z([1 8], [1 8]) = int32([100 101; 102 103]);
            d([1 8], [1 8]) = int32([100 101; 102 103]);
            tc.verifyEqual(z(:, :), d);
        end

        function scalarExpansion(tc)
            z = zarr.create(tc.store, [4 4], "float64", ChunkShape=[2 2]);
            z(:, :) = 7;
            tc.verifyEqual(z(:, :), 7 * ones(4));
            z(2:3, 2:3) = 0;
            tc.verifyEqual(z(2, 2), 0);
        end

        function fillValueForUnwritten(tc)
            z = zarr.create(tc.store, [6 6], "float64", ChunkShape=[3 3], FillValue=NaN);
            z(1:3, 1:3) = magic(3);
            out = z(:, :);
            tc.verifyEqual(out(1:3, 1:3), magic(3));
            tc.verifyTrue(all(isnan(out(4:6, :)), 'all'));
        end

        function readModifyWriteAcrossChunks(tc)
            z = zarr.create(tc.store, [9 9], "float64", ChunkShape=[4 4]);
            d = zeros(9);
            z(3:7, 3:7) = ones(5);
            d(3:7, 3:7) = ones(5);
            tc.verifyEqual(z(:, :), d);
        end

        function rankOneAndZero(tc)
            v = zarr.create(tc.store, 7, "int32", ChunkShape=3, Path="v");
            v(:) = int32((1:7)');
            tc.verifyEqual(v(2:5), int32((2:5)'));
            tc.verifyEqual(size(v), [7 1]);

            s = zarr.create(tc.store, [], "float64", Path="s");
            s.write(pi);
            tc.verifyEqual(s(), pi);
        end

        function outOfBoundsErrors(tc)
            z = zarr.create(tc.store, [4 4], "float64");
            tc.verifyError(@() z(5, 1), "zarr:Indexing");
            tc.verifyError(@() z(0, 1), "zarr:Indexing");
            function assignOOB()
                z(1:5, 1) = ones(5, 1);
            end
            tc.verifyError(@assignOOB, "zarr:Indexing");
        end

        function dtypePreserved(tc)
            for dt = ["int16", "uint64", "float32", "complex128", "bool", "float16"]
                z = zarr.create(tc.store, 5, dt, Path="dt_" + dt);
                d = interop_pattern(5, dt);
                z(:) = d;
                tc.verifyEqual(z(:), d, dt);
            end
        end

        function forder(tc)
            z = zarr.create(tc.store, [4 6], "float64", ChunkShape=[2 3], Order="F");
            d = reshape(1:24, [4 6]);
            z(:, :) = d;
            tc.verifyEqual(z(:, :), d);
            % metadata contains the transpose codec
            tc.verifyTrue(contains(char(z.meta.toJsonText()), '"transpose"'));
        end

        function resizeGrowShrink(tc)
            z = zarr.create(tc.store, [4 4], "float64", ChunkShape=[2 2]);
            z(:, :) = ones(4);
            z.resize([6 4]);
            out = z(:, :);
            tc.verifyEqual(out(1:4, :), ones(4));
            tc.verifyEqual(out(5:6, :), zeros(2, 4));
            z.resize([2 2]);
            tc.verifyEqual(z(:, :), ones(2));
            % shrunk-away chunks are deleted from the store
            tc.verifyFalse(tc.store.exists("c/1/1"));
        end

        function appendAlongDims(tc)
            z = zarr.create(tc.store, [2 3], "float64", ChunkShape=[2 2]);
            z(:, :) = ones(2, 3);
            z.append(2 * ones(2, 2), 2);
            tc.verifyEqual(z(:, :), [ones(2, 3), 2 * ones(2, 2)]);
            z.append(3 * ones(1, 5), 1);
            tc.verifyEqual(size(z), [3 5]);
            tc.verifyEqual(z(3, :), 3 * ones(1, 5));
        end

        function attributesPersist(tc)
            z = zarr.create(tc.store, 4, "float64", Attributes=struct('a', 1));
            z.setAttr('b', "two");
            z2 = zarr.open(tc.store);
            tc.verifyEqual(z2.attrs.a, 1);
            tc.verifyEqual(string(z2.attrs.b), "two");
        end

        function hierarchy(tc)
            g = zarr.create_group(tc.store);
            sub = g.createGroup("sub");
            sub.createArray("x", [2 2], "float64");
            zarr.create(tc.store, 3, "int8", Path="sub/deep/y");
            [an, gn] = g.children();
            tc.verifyEqual(gn, "sub");
            tc.verifyEmpty(an);
            [an2, gn2] = sub.children();
            tc.verifyTrue(ismember("x", an2) && ismember("deep", gn2));
            % implicit parents were created as groups
            node = zarr.open(tc.store, Path="sub/deep");
            tc.verifyClass(node, 'zarr.Group');
        end

        function overwriteProtection(tc)
            zarr.create(tc.store, 4, "float64", Path="x");
            tc.verifyError(@() zarr.create(tc.store, 4, "float64", Path="x"), ...
                "zarr:NodeExists");
            z = zarr.create(tc.store, 6, "int32", Path="x", Overwrite=true);
            tc.verifyEqual(z.dtype, "int32");
        end

        function arrayGroupConflict(tc)
            zarr.create(tc.store, 4, "float64", Path="x");
            tc.verifyError(@() zarr.create(tc.store, 4, "float64", Path="x/child"), ...
                "zarr:NodeExists");
        end

        function localStoreReopen(tc)
            tmp = fullfile(tempdir, "zm_test_" + string(feature('getpid')));
            cleaner = onCleanup(@() rmdirIf(tmp));
            z = zarr.create(char(tmp), [5 4], "int16", ChunkShape=[2 2], ...
                Codecs={zarr.codecs.GzipCodec(1), zarr.codecs.Crc32cCodec()});
            d = reshape(int16(1:20), [5 4]);
            z(:, :) = d;
            z2 = zarr.open(char(tmp));
            tc.verifyEqual(z2(:, :), d);
        end
    end
end

function rmdirIf(p)
if isfolder(p), rmdir(p, 's'); end
end
