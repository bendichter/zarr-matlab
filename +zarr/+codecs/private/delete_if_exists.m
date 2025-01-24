function delete_if_exists(files)
    % Delete files if they exist
    %
    % Parameters:
    %   files: cell array of file paths
    
    if ~iscell(files)
        files = {files};
    end
    
    for i = 1:numel(files)
        if exist(files{i}, 'file')
            delete(files{i});
        end
    end
end
