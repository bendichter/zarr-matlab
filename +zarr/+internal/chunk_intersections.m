function parts = chunk_intersections(start0, count, chunkShape)
%CHUNK_INTERSECTIONS Chunks intersecting a hyperrectangular region.
%   All inputs/outputs 0-based. start0, count, chunkShape are 1xR (R >= 1).
%   Returns a struct array with fields (each 1xR):
%     coords   - chunk grid indices
%     inStart  - start of the intersection within the chunk
%     inCount  - extent of the intersection
%     outStart - start of the intersection within the requested region

R = numel(chunkShape);
empty = struct('coords', {}, 'inStart', {}, 'inCount', {}, 'outStart', {});
if any(count <= 0)
    parts = empty;
    return
end

lists = cell(1, R);
nPer = zeros(1, R);
for d = 1:R
    s = start0(d);
    e = s + count(d) - 1;
    cs = chunkShape(d);
    ks = floor(s / cs):floor(e / cs);
    L = zeros(numel(ks), 4);  % [k, inStart, inCount, outStart]
    for i = 1:numel(ks)
        k = ks(i);
        a = max(s, k * cs);
        b = min(e, (k + 1) * cs - 1);
        L(i, :) = [k, a - k * cs, b - a + 1, a - s];
    end
    lists{d} = L;
    nPer(d) = numel(ks);
end

total = prod(nPer);
parts = repmat(struct('coords', zeros(1, R), 'inStart', zeros(1, R), ...
    'inCount', zeros(1, R), 'outStart', zeros(1, R)), total, 1);
sub = ones(1, R);
for t = 1:total
    for d = 1:R
        row = lists{d}(sub(d), :);
        parts(t).coords(d) = row(1);
        parts(t).inStart(d) = row(2);
        parts(t).inCount(d) = row(3);
        parts(t).outStart(d) = row(4);
    end
    d = R;  % increment odometer, last dimension fastest
    while d >= 1
        sub(d) = sub(d) + 1;
        if sub(d) <= nPer(d)
            break
        end
        sub(d) = 1;
        d = d - 1;
    end
end
end
