function mex_smoke()
%MEX_SMOKE Quick round-trip checks of the built MEX codecs (used by CI).

a = uint8(repmat('zarr', 1, 500));
c = zarr.internal.zstd_mex('compress', a, 19, 1);
assert(isequal(zarr.internal.zstd_mex('decompress', c), a), 'zstd round trip');
b = zarr.internal.blosc_mex('compress', a, 'zstd', 5, 2, 2);
assert(isequal(zarr.internal.blosc_mex('decompress', b), a), 'blosc round trip');
b2 = zarr.internal.blosc_mex('compress', a, 'lz4', 5, 1, 1);
assert(isequal(zarr.internal.blosc_mex('decompress', b2), a), 'blosc lz4 round trip');
assert(zarr.internal.crc32c_mex(uint8('123456789')) == uint32(hex2dec('E3069283')), 'crc32c KAT');
disp('mex smoke ok');
end
