function build_mex()
%BUILD_MEX Build the zstd and blosc MEX codecs into +zarr/+internal.
%   Links against Homebrew (macOS) or system libzstd / libblosc. Static
%   libraries are preferred when present so the binaries are relocatable.

root = fileparts(fileparts(mfilename('fullpath')));
outDir = fullfile(root, '+zarr', '+internal');
srcDir = fullfile(root, 'mex');

% Library prefix resolution: ZARR_MATLAB_LIBS env var wins (a prefix with
% lib/ and include/ containing arch-matched static libs), then Homebrew.
override = string(getenv("ZARR_MATLAB_LIBS"));
if strlength(override) > 0
    zstdPrefix = override;
    bloscPrefix = override;
else
    zstdPrefix = firstExisting(["/opt/homebrew/opt/zstd", "/usr/local/opt/zstd", "/usr"]);
    bloscPrefix = firstExisting(["/opt/homebrew/opt/c-blosc", "/usr/local/opt/c-blosc", "/usr"]);
end

buildOne(fullfile(srcDir, 'zstd_mex.c'), outDir, zstdPrefix, "zstd");
buildOne(fullfile(srcDir, 'blosc_mex.c'), outDir, bloscPrefix, "blosc");
mex('-silent', fullfile(srcDir, 'crc32c_mex.c'), '-outdir', char(outDir), ...
    '-output', 'crc32c_mex');
fprintf('MEX codecs built into %s\n', outDir);
end

function buildOne(src, outDir, prefix, libname)
inc = "-I" + fullfile(prefix, "include");
staticLib = fullfile(prefix, "lib", "lib" + libname + ".a");
if isfile(staticLib)
    linkArgs = {char(staticLib)};
else
    linkArgs = {char("-L" + fullfile(prefix, "lib")), char("-l" + libname)};
end
[~, name] = fileparts(src);
mex('-silent', char(inc), char(src), linkArgs{:}, '-outdir', char(outDir), '-output', name);
end

function p = firstExisting(candidates)
for c = candidates
    if isfolder(c)
        p = c;
        return
    end
end
error("zarr:BuildError", "None of the library prefixes exist: %s", strjoin(candidates, ", "));
end
