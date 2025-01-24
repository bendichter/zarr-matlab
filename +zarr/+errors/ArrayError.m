classdef ArrayError < zarr.errors.ZarrError
    % ARRAYERROR Error for array-related issues
    %   ArrayError is thrown when there are issues with Zarr array operations,
    %   such as invalid shapes, types, or indexing operations.
    
    methods
        function obj = ArrayError(message, varargin)
            % Create a new ArrayError
            %
            % Parameters:
            %   message: string
            %       Error message, can include sprintf-style formatting
            %   varargin: any
            %       Additional arguments for message formatting
            
            obj@zarr.errors.ZarrError(['Array Error: ' message], varargin{:});
        end
    end
end
