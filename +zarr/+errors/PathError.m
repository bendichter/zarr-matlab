classdef PathError < zarr.errors.ZarrError
    % PATHERROR Error for path-related issues
    %   PathError is thrown when there are issues with Zarr paths,
    %   such as invalid path formats or path resolution failures.
    
    methods
        function obj = PathError(message, varargin)
            % Create a new PathError
            %
            % Parameters:
            %   message: string
            %       Error message, can include sprintf-style formatting
            %   varargin: any
            %       Additional arguments for message formatting
            
            obj@zarr.errors.ZarrError(['Path Error: ' message], varargin{:});
        end
    end
end
