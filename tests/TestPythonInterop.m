classdef TestPythonInterop < matlab.unittest.TestCase
    %Bidirectional interop against zarr-python (skipped if no python env).
    %   Uses the project .venv (see README) or the ZARR_MATLAB_PYTHON env var.

    properties
        python
        root
    end

    methods (TestClassSetup)
        function findPython(tc)
            tc.root = fileparts(fileparts(mfilename('fullpath')));
            candidates = [string(getenv('ZARR_MATLAB_PYTHON')), ...
                fullfile(tc.root, '.venv', 'bin', 'python'), "python3"];
            tc.python = "";
            for c = candidates
                if strlength(c) == 0, continue; end
                [status, ~] = system("""" + c + """ -c ""import zarr,sys; sys.exit(0 if zarr.__version__ >= '3' else 1)""");
                if status == 0
                    tc.python = c;
                    break
                end
            end
            tc.assumeTrue(strlength(tc.python) > 0, ...
                'zarr-python >= 3 not found; skipping interop tests');
        end
    end

    methods (Test)
        function bidirectional(tc)
            work = fullfile(tempdir, "zm_interop_" + string(feature('getpid')));
            cleaner = onCleanup(@() rmdirIf(work));
            mkdir(work);
            pyStore = fullfile(work, 'py_store');
            mlStore = fullfile(work, 'ml_store');
            toolsDir = fullfile(tc.root, 'tools');

            run_py = @(script, arg) system( ...
                "cd """ + toolsDir + """ && """ + tc.python + """ " + script + " """ + arg + """");

            [status, out] = run_py("interop_write.py", pyStore);
            tc.assertEqual(status, 0, out);

            addpath(toolsDir);
            interop_matlab(char(pyStore), char(mlStore));  % asserts internally

            [status, out] = run_py("interop_verify.py", mlStore);
            tc.assertEqual(status, 0, out);
        end
    end
end

function rmdirIf(p)
if isfolder(p), rmdir(p, 's'); end
end
