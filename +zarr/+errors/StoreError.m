classdef StoreError < zarr.errors.ZarrError
    % STOREERROR Error for storage-related issues
    %   StoreError is thrown when there are issues with Zarr storage operations,
    %   such as failed reads/writes or invalid storage paths.
    
    methods
        function obj = StoreError(message, varargin)
            % Create a new StoreError
            %
            % Parameters:
            %   message: string
            %       Error message, can include sprintf-style formatting
            %   varargin: any
            %       Additional arguments for message formatting
            
            obj@zarr.errors.ZarrError(['Store Error: ' message], varargin{:});
        end
    end
end
