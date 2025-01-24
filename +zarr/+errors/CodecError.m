classdef CodecError < zarr.errors.ZarrError
    % CODECERROR Error thrown by compression codecs
    %   Base class for all codec-related errors in Zarr.
    %   Specific error messages should indicate the nature of the codec error,
    %   such as invalid compression settings or compression/decompression failures.
    
    methods
        function obj = CodecError(msg)
            % Create a new CodecError
            %
            % Parameters:
            %   msg: string
            %       Error message
            
            obj = obj@zarr.errors.ZarrError(msg);
        end
    end
end
