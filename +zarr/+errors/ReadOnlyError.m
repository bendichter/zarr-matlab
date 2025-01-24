classdef ReadOnlyError < zarr.errors.ZarrError
    % READONLYERROR Error for attempting to modify read-only data
    %   ReadOnlyError is thrown when attempting to modify data in a read-only
    %   store or array.
    
    methods
        function obj = ReadOnlyError(message, varargin)
            % Create a new ReadOnlyError
            %
            % Parameters:
            %   message: string
            %       Error message, can include sprintf-style formatting
            %   varargin: any
            %       Additional arguments for message formatting
            
            obj@zarr.errors.ZarrError(['Read Only Error: ' message], varargin{:});
        end
    end
end
