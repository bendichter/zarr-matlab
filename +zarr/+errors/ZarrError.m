classdef ZarrError < MException
    % ZARRERROR Base class for Zarr-specific errors
    %   ZarrError provides a base class for all Zarr-specific errors. It extends
    %   MATLAB's MException class to provide consistent error handling throughout
    %   the Zarr library.
    %
    %   All specialized Zarr errors (MetadataError, StoreError, etc.) inherit
    %   from this base class.
    
    methods
        function obj = ZarrError(message, varargin)
            % Create a new ZarrError
            %
            % Parameters:
            %   message: string
            %       Error message, can include sprintf-style formatting
            %   varargin: any
            %       Additional arguments for message formatting
            
            % Format message if additional arguments provided
            if ~isempty(varargin)
                message = sprintf(message, varargin{:});
            end
            
            % Call superclass constructor with Zarr identifier
            obj@MException('Zarr:Error', message);
        end
    end
end
