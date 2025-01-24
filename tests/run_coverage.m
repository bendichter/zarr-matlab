function run_coverage()
% RUN_COVERAGE Run test suite with code coverage analysis
%   This function runs all tests in the zarr-matlab test suite and generates
%   a code coverage report in the coverage_report directory.

% Import required packages
import matlab.unittest.TestRunner;
import matlab.unittest.plugins.CodeCoveragePlugin;
import matlab.unittest.plugins.codecoverage.CoverageReport;

% Create test runner with text output
runner = TestRunner.withTextOutput;

% Configure coverage report
reportFolder = 'coverage_report';
if exist(reportFolder, 'dir')
    rmdir(reportFolder, 's');
end

% Get the root zarr-matlab directory
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

% Create coverage plugin for zarr-matlab folder
plugin = CodeCoveragePlugin.forFolder(...
    rootDir, ...
    'IncludingSubfolders', true, ...
    'Producing', CoverageReport(reportFolder));

% Add plugin to runner
runner.addPlugin(plugin);

% Run test suite
results = runner.run(testsuite(fullfile(rootDir, 'tests')));

% Display summary
disp(' ');
disp('Test Summary:');
disp(['  ' num2str(sum([results.Passed])) ' tests passed']);
disp(['  ' num2str(sum([results.Failed])) ' tests failed']);
disp(['  ' num2str(sum([results.Incomplete])) ' tests incomplete']);

% Open coverage report
web(['file://' fullfile(pwd, reportFolder, 'index.html')]);

end
