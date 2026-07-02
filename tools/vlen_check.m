function vlen_check()
% read python-written string/bytes arrays (scratch/probe from the format probe)
s = zarr.open('scratch/probe', Path='s');
expected = ["hello"; native2unicode(uint8([207 135 206 177 206 175 207 129 206 181 207 132 206 181]), 'UTF-8'); ""; "zarr"];
assert(isequal(s.read(), expected), 'py string read');
b = zarr.open('scratch/probe', Path='b');
v = b.read();
assert(isequal(v{1}, uint8('ab')) && isempty(v{2}) && isequal(v{3}, uint8([0 255])), 'py bytes read');

% MATLAB round trips: 2-D with gzip, fill values, unicode
st = zarr.stores.MemoryStore();
z = zarr.create(st, [3 4], 'string', ChunkShape=[2 2], Path='vs', ...
    Codecs={zarr.codecs.GzipCodec(5)}, FillValue="?");
uni = native2unicode(uint8([230 151 165 230 156 172 232 170 158]), 'UTF-8');  % 日本語
z(1:2, 1:2) = ["a" "bb"; "ccc" string(uni)];
out = z(:, :);
assert(out(1, 1) == "a" && out(2, 2) == string(uni) && out(3, 4) == "?", 'string rt');

zb = zarr.create(st, 5, 'bytes', ChunkShape=2, Path='vb');
zb(:) = {uint8([1 2]); uint8([]); uint8(255); uint8([9 8 7]); uint8(0)};
ob = zb(:);
assert(isequal(ob{4}, uint8([9 8 7])) && isempty(ob{2}), 'bytes rt');

% sharded strings with partial reads
zs = zarr.create(st, [4 4], 'string', ChunkShape=[2 2], ShardShape=[4 4], Path='ss');
d = reshape(string(1:16), [4 4]);
zs(:, :) = d;
assert(isequal(zs(2:3, 2:3), d(2:3, 2:3)), 'sharded string');
disp('VLEN OK')
end
