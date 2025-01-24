classdef MetadataError < zarr.errors.ZarrError
    % METADATAERROR Error for metadata-related issues
    %   MetadataError is thrown when there are issues with Zarr metadata,
    %   such as invalid or missing metadata fields.
    
    methods
        function obj = MetadataError(message, varargin)
            % Create a new MetadataError
            %
            % Parameters:
            %   message: string
            %       Error message, can include sprintf-style formatting
            %   varargin: any
            %       Additional arguments for message formatting
            
            obj@zarr.errors.ZarrError(['Metadata Error: ' message], varargin{:});
        end
    end
end
