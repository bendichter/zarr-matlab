classdef TestStructuredDtype < matlab.unittest.TestCase
    %"structured" (compound record) and "fixed_length_utf32" data types.
    %
    %   Neither is part of the Zarr v3 specification -- both are unstable,
    %   unspecified zarr-python extensions (zarr-python itself raises
    %   UnstableSpecificationWarning when writing them). Support exists here
    %   to read real-world files that use them (observed in some NWB Zarr v3
    %   exports via hdmf-zarr, e.g. IntracellularRecordingsTable index
    %   columns and PlaneSegmentation pixel_mask/voxel_mask columns).

    methods (Static)
        function info = structInfo()
            % {a: int32, b: float64, c: fixed_length_utf32(32 bytes)}
            dtypeJson = struct('name', "structured", 'configuration', struct( ...
                'fields', {{ ...
                    {'a', 'int32'}; ...
                    {'b', 'float64'}; ...
                    {'c', struct('name', 'fixed_length_utf32', 'configuration', struct('length_bytes', 32))} ...
                }}));
            info = zarr.internal.dtype_info(dtypeJson);
        end
    end

    methods (Test)
        function fixedUtf32Itemsize(tc)
            dtypeJson = struct('name', "fixed_length_utf32", 'configuration', struct('length_bytes', 16));
            info = zarr.internal.dtype_info(dtypeJson);
            tc.verifyEqual(info.itemsize, 16);
            tc.verifyEqual(info.matlabClass, "string");
            tc.verifyFalse(info.isVlen);
        end

        function structuredFieldLayout(tc)
            info = tc.structInfo();
            tc.verifyEqual(info.itemsize, 4 + 8 + 32);
            tc.verifyEqual([info.fields.Name], ["a", "b", "c"]);
            tc.verifyEqual([info.fields.Offset], [0, 4, 12]);
        end

        function unsupportedFixedUtf32ConfigErrors(tc)
            tc.verifyError(@() zarr.internal.dtype_info( ...
                struct('name', "fixed_length_utf32", 'configuration', struct())), ...
                "zarr:InvalidMetadata");
        end

        function fixedUtf32RoundTrip(tc, endianCase)
            info = zarr.internal.dtype_info( ...
                struct('name', "fixed_length_utf32", 'configuration', struct('length_bytes', 64)));
            codec = zarr.codecs.BytesCodec(endianCase);
            values = ["hi"; "utf32 test"; ""];
            bytes = codec.encode(values, info, 3);
            back = codec.decode(bytes, info, 3, []);
            tc.verifyEqual(back, values);
        end

        function fixedUtf32ExceedingCapacityErrors(tc)
            info = zarr.internal.dtype_info( ...
                struct('name', "fixed_length_utf32", 'configuration', struct('length_bytes', 8)));
            codec = zarr.codecs.BytesCodec();
            tc.verifyError(@() codec.encode("way too long for capacity", info, 1), ...
                "zarr:ValueError");
        end

        function structuredRoundTrip(tc, endianCase)
            info = tc.structInfo();
            records(1, 1).a = int32(10);
            records(1, 1).b = 3.5;
            records(1, 1).c = "hi";
            records(2, 1).a = int32(-5);
            records(2, 1).b = -2.25;
            records(2, 1).c = "world";

            codec = zarr.codecs.BytesCodec(endianCase);
            bytes = codec.encode(records, info, [2]);
            tc.verifyEqual(numel(bytes), 2 * info.itemsize);

            back = codec.decode(bytes, info, [2], []);
            tc.verifyEqual(back(1).a, records(1).a);
            tc.verifyEqual(back(1).b, records(1).b);
            tc.verifyEqual(back(1).c, records(1).c);
            tc.verifyEqual(back(2).a, records(2).a);
            tc.verifyEqual(back(2).b, records(2).b);
            tc.verifyEqual(back(2).c, records(2).c);
        end

        function structuredFillValueRoundTrip(tc)
            info = tc.structInfo();
            fv = struct('a', int32(0), 'b', 0.0, 'c', "");
            meta = zarr.metadata.ArrayMetadata();
            meta.shape = 3;
            meta.dataType = "structured";
            meta.dataTypeConfig = info.config;
            meta.chunkShape = 3;
            meta.fillValue = fv;
            meta.codecs = {zarr.codecs.BytesCodec()};

            meta2 = zarr.metadata.ArrayMetadata.fromJsonText(meta.toJsonText());
            tc.verifyEqual(meta2.fillValue.a, fv.a);
            tc.verifyEqual(meta2.fillValue.b, fv.b);
            tc.verifyEqual(meta2.fillValue.c, fv.c);
        end

        function arrayMetadataRoundTripPreservesStructuredDataType(tc)
            info = tc.structInfo();
            meta = zarr.metadata.ArrayMetadata();
            meta.shape = 2;
            meta.dataType = "structured";
            meta.dataTypeConfig = info.config;
            meta.chunkShape = 2;
            meta.fillValue = struct('a', int32(0), 'b', 0.0, 'c', "");
            meta.codecs = {zarr.codecs.BytesCodec()};

            meta2 = zarr.metadata.ArrayMetadata.fromJsonText(meta.toJsonText());
            info2 = zarr.internal.dtype_info(meta2.dataType, meta2.dataTypeConfig);
            tc.verifyEqual(info2.itemsize, info.itemsize);
            tc.verifyEqual([info2.fields.Name], [info.fields.Name]);
        end

        function nestedStructuredField(tc)
            % A structured field that is itself structured.
            innerJson = struct('name', "structured", 'configuration', struct( ...
                'fields', {{{'x', 'int16'}; {'y', 'int16'}}}));
            outerJson = struct('name', "structured", 'configuration', struct( ...
                'fields', {{{'point', innerJson}; {'label', struct('name', 'fixed_length_utf32', ...
                    'configuration', struct('length_bytes', 8))}}}));
            info = zarr.internal.dtype_info(outerJson);
            tc.verifyEqual(info.itemsize, 4 + 8);

            record.point = struct('x', int16(1), 'y', int16(-2));
            record.label = "pt";
            codec = zarr.codecs.BytesCodec();
            bytes = codec.encode(record, info, []);
            back = codec.decode(bytes, info, [], []);
            tc.verifyEqual(back.point.x, record.point.x);
            tc.verifyEqual(back.point.y, record.point.y);
            tc.verifyEqual(back.label, record.label);
        end

        function structuredArrayEndToEnd(tc)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tempFixture = tc.applyFixture(TemporaryFolderFixture);
            storePath = fullfile(tempFixture.Folder, "structured.zarr");

            info = tc.structInfo();
            meta = zarr.metadata.ArrayMetadata();
            meta.shape = 2;
            meta.dataType = "structured";
            meta.dataTypeConfig = info.config;
            meta.chunkShape = 2;
            meta.fillValue = struct('a', int32(0), 'b', 0.0, 'c', "");
            meta.codecs = {zarr.codecs.BytesCodec()};

            store = zarr.stores.LocalStore(storePath);
            store.set("zarr.json", unicode2native(char(meta.toJsonText()), 'UTF-8'));

            records(1, 1).a = int32(1);
            records(1, 1).b = 1.5;
            records(1, 1).c = "one";
            records(2, 1).a = int32(2);
            records(2, 1).b = 2.5;
            records(2, 1).c = "two";

            z = zarr.Array(store, "", meta);
            z.write(records);

            reopened = zarr.open(storePath);
            back = reopened.read();
            tc.verifyEqual(back(1).a, records(1).a);
            tc.verifyEqual(back(1).c, records(1).c);
            tc.verifyEqual(back(2).b, records(2).b);
        end
    end

    properties (TestParameter)
        endianCase = {"little", "big"};
    end
end
