classdef TestDocs < matlab.unittest.TestCase
    %Executes every ```matlab code block in docs/**/*.md.
    %   Each page runs top-to-bottom as one script in a fresh temporary
    %   working directory, so examples share state within a page but not
    %   across pages, and relative store paths ("example.zarr") are sandboxed.
    %   Blocks fenced as ```python / ```text / ```diff are not executed.

    properties (TestParameter)
        docPage = TestDocs.listPages()
    end

    methods (Static)
        function pages = listPages()
            docsDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'docs');
            entries = dir(fullfile(docsDir, '**', '*.md'));
            pages = cell(1, numel(entries));
            for i = 1:numel(entries)
                rel = erase(string(fullfile(entries(i).folder, entries(i).name)), ...
                    string(docsDir) + filesep);
                pages{i} = char(strjoin(split(rel, filesep), "/"));
            end
        end

        function code = extractMatlabBlocks(mdFile)
            lines = readlines(mdFile);
            code = strings(0, 1);
            inBlock = false;
            for i = 1:numel(lines)
                line = lines(i);
                if ~inBlock && strtrim(line) == "```matlab"
                    inBlock = true;
                elseif inBlock && startsWith(strtrim(line), "```")
                    inBlock = false;
                    code(end + 1, 1) = "";  %#ok<AGROW> blank line between blocks
                elseif inBlock
                    code(end + 1, 1) = line; %#ok<AGROW>
                end
            end
            if inBlock
                error("zarr:TestDocs", "Unterminated ```matlab fence in %s", mdFile);
            end
        end
    end

    methods (Test)
        function pageRunsClean(tc, docPage)
            docsDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'docs');
            mdFile = fullfile(docsDir, docPage);
            code = TestDocs.extractMatlabBlocks(mdFile);
            if isempty(code)
                return  % page has no executable examples
            end

            sandbox = fullfile(tempdir, "zm_docs_" + string(feature('getpid')) + ...
                "_" + matlab.lang.makeValidName(docPage));
            if isfolder(sandbox), rmdir(sandbox, 's'); end
            mkdir(sandbox);
            cleanupDir = onCleanup(@() rmdirIf(sandbox));

            scriptName = "doc_page_snippets";
            fid = fopen(fullfile(sandbox, scriptName + ".m"), 'w', 'n', 'UTF-8');
            fwrite(fid, unicode2native(char(strjoin(code, newline)), 'UTF-8'));
            fclose(fid);

            origDir = cd(sandbox);
            cleanupCd = onCleanup(@() cd(origDir));
            try
                evalc(char(scriptName));  % suppress example output
            catch err
                tc.verifyFail(sprintf('%s failed: %s\n%s', docPage, ...
                    err.identifier, err.message));
            end
        end
    end
end

function rmdirIf(p)
if isfolder(p), rmdir(p, 's'); end
end
