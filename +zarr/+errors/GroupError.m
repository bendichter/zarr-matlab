classdef GroupError < zarr.errors.ZarrError
    % GROUPERROR Error for group-related issues
    %   GroupError is thrown when there are issues with Zarr group operations,
    %   such as invalid group creation, deletion, or navigation.
    
    methods
        function obj = GroupError(message, varargin)
            % Create a new GroupError
            %
            % Parameters:
            %   message: string
            %       Error message, can include sprintf-style formatting
            %   varargin: any
            %       Additional arguments for message formatting
            
            obj@zarr.errors.ZarrError(['Group Error: ' message], varargin{:});
        end
    end
end
