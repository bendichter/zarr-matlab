function run_tests()
%RUN_TESTS Run the full test suite; error (nonzero exit in -batch) on failure.

import matlab.unittest.TestSuite
import matlab.unittest.TestRunner
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoberturaFormat

root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root, 'tools'));

suite = TestSuite.fromFolder(fullfile(root, 'tests'), 'IncludingSubfolders', true);
runner = TestRunner.withTextOutput();

reportDirectory = fullfile(root, 'docs', 'reports');
if ~isfolder(reportDirectory)
    mkdir(reportDirectory);
end
coverageFile = fullfile(reportDirectory, 'codecoverage.xml');
runner.addPlugin(CodeCoveragePlugin.forFolder(fullfile(root, '+zarr'), ...
    'IncludingSubfolders', true, 'Producing', CoberturaFormat(coverageFile)));

results = runner.run(suite);
disp(table(results));
if any([results.Failed]) || any([results.Incomplete] & ~[results.Passed] & ~arrayfun(@wasSkipped, results))
    error("zarr:TestsFailed", "%d test(s) failed.", nnz([results.Failed]));
end
fprintf('%d passed, %d skipped\n', nnz([results.Passed]), nnz(arrayfun(@wasSkipped, results)));
end

function tf = wasSkipped(r)
tf = r.Incomplete && ~r.Failed;
end
