classdef TestZipAndConsolidated < matlab.unittest.TestCase
    %ZipStore and consolidated metadata.

    properties
        work
    end

    methods (TestMethodSetup)
        function makeWork(tc)
            tc.work = fullfile(tempdir, "zm_zip_" + string(feature('getpid')) + ...
                "_" + string(randi(1e9)));
            mkdir(tc.work);
        end
    end

    methods (TestMethodTeardown)
        function rmWork(tc)
            if isfolder(tc.work), rmdir(tc.work, 's'); end
        end
    end

    methods (Test)
        function zipWriteReadRoundTrip(tc)
            p = fullfile(tc.work, "a.zarr.zip");
            ws = zarr.stores.ZipStore(p, Mode="w");
            zarr.create_group(ws, Attributes=struct('k', 1));
            z = zarr.create(ws, [6 8], "float64", Path="d", ChunkShape=[3 4], ...
                Codecs={zarr.codecs.GzipCodec(5)});
            d = reshape(1:48, [6 8]);
            z.write(d);
            % readable before close via the pending map
            tc.verifyEqual(z(2:3, 4:6), d(2:3, 4:6));
            ws.close();

            rs = zarr.stores.ZipStore(p);
            g = zarr.open(rs);
            tc.verifyEqual(g.attrs.k, 1);
            tc.verifyEqual(g.item("d").read(), d);
            [an, ~] = g.children();
            tc.verifyEqual(an, "d");
            rs.close();
        end

        function zipReadOnlyEnforced(tc)
            p = fullfile(tc.work, "b.zarr.zip");
            ws = zarr.stores.ZipStore(p, Mode="w");
            zarr.create_group(ws);
            ws.close();
            rs = zarr.stores.ZipStore(p);
            tc.verifyError(@() rs.set("x", uint8(1)), "zarr:StoreError");
            rs.close();
            tc.verifyError(@() rs.list(), "zarr:StoreError");  % closed
        end

        function consolidateAndReadBack(tc)
            root = fullfile(tc.work, "c.zarr");
            ls = zarr.stores.LocalStore(root);
            zarr.create_group(ls, Attributes=struct('t', "root"));
            zarr.create(ls, [4 4], "float64", Path="x", ChunkShape=[2 2]).write(magic(4));
            zarr.create(ls, 3, "int32", Path="sub/y").write(int32((1:3)'));
            zarr.consolidate_metadata(ls);

            g = zarr.open(root);
            tc.verifyNotEmpty(g.meta.consolidated);
            [an, gn] = g.children();
            tc.verifyEqual(an, "x");
            tc.verifyEqual(gn, "sub");
            tc.verifyEqual(g.item("sub").item("y").read(), int32((1:3)'));
            tc.verifyEqual(g.item("x").read(), magic(4));
            % group attrs survive consolidation
            tc.verifyEqual(string(g.attrs.t), "root");
        end

        function consolidatedAvoidsStoreReads(tc)
            root = fullfile(tc.work, "d.zarr");
            ls = zarr.stores.LocalStore(root);
            zarr.create_group(ls);
            zarr.create(ls, 3, "float64", Path="deep/nested/x").write((1:3)');
            zarr.consolidate_metadata(ls);

            probe = ProbeLocalStore(root);
            g = zarr.open(probe);
            probe.resetCount();
            node = g.item("deep").item("nested").item("x");
            tc.verifyEqual(probe.nGets, 0, 'metadata lookups served from memory');
            tc.verifyEqual(node.read(), (1:3)');  % data reads still hit the store
        end

        function consolidationPreservedOnAttrUpdate(tc)
            root = fullfile(tc.work, "e.zarr");
            ls = zarr.stores.LocalStore(root);
            zarr.create_group(ls);
            zarr.create(ls, 2, "int8", Path="x");
            zarr.consolidate_metadata(ls);
            g = zarr.open(root);
            g.setAttr('new', 42);
            g2 = zarr.open(root);
            tc.verifyEqual(g2.attrs.new, 42);
            tc.verifyNotEmpty(g2.meta.consolidated, 'consolidation survives setAttr');
        end
    end
end
