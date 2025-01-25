% Build script for zstd MEX files

% Source directories
current_dir = pwd;
project_root = fullfile(current_dir, '..', '..', '..', '..');
zstd_dir = fullfile(project_root, 'numcodecs', 'c-blosc', 'internal-complibs', 'zstd-1.5.6');

% Source files
src_files = {
    % Common files
    fullfile(zstd_dir, 'common', 'debug.c')
    fullfile(zstd_dir, 'common', 'entropy_common.c')
    fullfile(zstd_dir, 'common', 'error_private.c')
    fullfile(zstd_dir, 'common', 'fse_decompress.c')
    fullfile(zstd_dir, 'common', 'pool.c')
    fullfile(zstd_dir, 'common', 'threading.c')
    fullfile(zstd_dir, 'common', 'xxhash.c')
    fullfile(zstd_dir, 'common', 'zstd_common.c')
    % Compression files
    fullfile(zstd_dir, 'compress', 'fse_compress.c')
    fullfile(zstd_dir, 'compress', 'hist.c')
    fullfile(zstd_dir, 'compress', 'huf_compress.c')
    fullfile(zstd_dir, 'compress', 'zstd_compress.c')
    fullfile(zstd_dir, 'compress', 'zstd_compress_literals.c')
    fullfile(zstd_dir, 'compress', 'zstd_compress_sequences.c')
    fullfile(zstd_dir, 'compress', 'zstd_compress_superblock.c')
    fullfile(zstd_dir, 'compress', 'zstd_double_fast.c')
    fullfile(zstd_dir, 'compress', 'zstd_fast.c')
    fullfile(zstd_dir, 'compress', 'zstd_lazy.c')
    fullfile(zstd_dir, 'compress', 'zstd_ldm.c')
    fullfile(zstd_dir, 'compress', 'zstd_opt.c')
    % Decompression files
    fullfile(zstd_dir, 'decompress', 'huf_decompress.c')
    fullfile(zstd_dir, 'decompress', 'zstd_ddict.c')
    fullfile(zstd_dir, 'decompress', 'zstd_decompress.c')
    fullfile(zstd_dir, 'decompress', 'zstd_decompress_block.c')
};

% Verify all source files exist
for i = 1:numel(src_files)
    if ~exist(src_files{i}, 'file')
        error('Source file not found: %s', src_files{i});
    end
end

% Build compression MEX file
fprintf('Building zstdmex...\n');
mex('-v', ...
    'COMPFLAGS="$COMPFLAGS -O3"', ...
    ['-I' fullfile(zstd_dir)], ...
    ['-I' fullfile(zstd_dir, 'common')], ...
    ['-I' fullfile(zstd_dir, 'compress')], ...
    ['-I' fullfile(zstd_dir, 'decompress')], ...
    '-DXXH_NAMESPACE=ZSTD_', ...
    '-DZSTD_LEGACY_SUPPORT=0', ...
    'zstdmex.c', ...
    src_files{:});

% Build decompression MEX file
fprintf('Building zstddmex...\n');
mex('-v', ...
    'COMPFLAGS="$COMPFLAGS -O3"', ...
    ['-I' fullfile(zstd_dir)], ...
    ['-I' fullfile(zstd_dir, 'common')], ...
    ['-I' fullfile(zstd_dir, 'compress')], ...
    ['-I' fullfile(zstd_dir, 'decompress')], ...
    '-DXXH_NAMESPACE=ZSTD_', ...
    '-DZSTD_LEGACY_SUPPORT=0', ...
    'zstddmex.c', ...
    src_files{:});

fprintf('Build complete.\n');
