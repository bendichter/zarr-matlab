function bench()
%BENCH Rough throughput benchmark: write + read a ~200 MB single array
%   under different codec configurations. Reports MB/s of logical data.

root = fullfile(tempdir, "zm_bench");
cleaner = onCleanup(@() rmdirIf(root));

shape = [5000 5000];             % 200 MB float64
data = randn(shape) + reshape(repmat(1:shape(2), shape(1), 1), shape);  % compressible-ish
mb = numel(data) * 8 / 1e6;

configs = {
    "raw (bytes only)",      {}, []
    "gzip-1",                {zarr.codecs.GzipCodec(1)}, []
    "zstd-3",                {zarr.codecs.ZstdCodec(3)}, []
    "blosc zstd-3 shuffle",  {zarr.codecs.BloscCodec(cname="zstd", clevel=3)}, []
    "zstd-3 sharded",        {zarr.codecs.ZstdCodec(3)}, [2500 2500]
    };

fprintf('%-22s %10s %10s %12s\n', 'config', 'write MB/s', 'read MB/s', 'stored MB');
for i = 1:size(configs, 1)
    if isfolder(root), rmdir(root, 's'); end
    args = {};
    if ~isempty(configs{i, 3})
        args = {'ShardShape', configs{i, 3}};
    end
    z = zarr.create(char(root), shape, "float64", 'ChunkShape', [500 500], ...
        'Codecs', configs{i, 2}, args{:});
    tW = tic;
    z.write(data);
    tw = toc(tW);
    tR = tic;
    out = z.read();
    tr = toc(tR);
    assert(isequal(out, data));
    d = dir(fullfile(root, '**', '*'));
    stored = sum([d(~[d.isdir]).bytes]) / 1e6;
    fprintf('%-22s %10.0f %10.0f %12.1f\n', configs{i, 1}, mb / tw, mb / tr, stored);
end

% partial read latency on sharded layout (one inner chunk of a big shard)
tP = tic;
z(100:200, 100:200);
fprintf('\npartial 101x101 read from sharded store: %.1f ms\n', toc(tP) * 1000);
end

function rmdirIf(p)
if isfolder(p), rmdir(p, 's'); end
end
