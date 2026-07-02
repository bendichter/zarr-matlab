function run_tests()
%RUN_TESTS Run the full test suite; error (nonzero exit in -batch) on failure.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root, 'tools'));
results = runtests(fullfile(root, 'tests'));
disp(table(results));
if any([results.Failed]) || any([results.Incomplete] & ~[results.Passed] & ~arrayfun(@wasSkipped, results))
    error("zarr:TestsFailed", "%d test(s) failed.", nnz([results.Failed]));
end
fprintf('%d passed, %d skipped\n', nnz([results.Passed]), nnz(arrayfun(@wasSkipped, results)));
end

function tf = wasSkipped(r)
tf = r.Incomplete && ~r.Failed;
end
