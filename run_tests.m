function run_tests()
    % Add zarr-matlab to path
    addpath(genpath(pwd));
    
    % Create test suite from test folder
    suite = testsuite('tests');
    
    % Create test runner
    runner = matlab.unittest.TestRunner.withTextOutput('Verbosity', matlab.unittest.Verbosity.Detailed);
    
    % Run tests and collect results
    results = runner.run(suite);
    
    % Display summary
    disp(' ');
    disp('Test Summary:');
    disp(['  ' num2str(sum([results.Passed])) ' tests passed']);
    disp(['  ' num2str(sum([results.Failed])) ' tests failed']);
    disp(['  ' num2str(sum([results.Incomplete])) ' tests incomplete']);
    
    % If there are failures, display them
    if any([results.Failed])
        disp(' ');
        disp('Failed Tests:');
        for i = 1:numel(results)
            if results(i).Failed
                disp(['  ' results(i).Name]);
                disp(['    ' results(i).Details.DiagnosticRecord.Report]);
            end
        end
    end
end
