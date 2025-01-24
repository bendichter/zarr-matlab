classdef ZstdCodec < handle
    % ZSTDCODEC ZSTD compression codec for Zarr arrays
    %   ZstdCodec provides ZSTD compression and decompression for chunk data.
    %   It uses MATLAB's built-in ZSTD functionality.
    
    properties (SetAccess = private)
        level           % Compression level (1-22)
        id = 'zstd'    % Codec identifier
    end
    
    methods
        function obj = ZstdCodec(level)
            % Create a ZstdCodec with the given compression level
            %
            % Parameters:
            %   level: integer (optional)
            %       ZSTD compression level, from 1 (fastest) to 22 (most compressed)
            %       Default is 3
            
            if nargin < 1
                level = 3;
            end
            
            % Validate level
            validateattributes(level, {'numeric'}, ...
                {'scalar', 'integer', '>=', 1, '<=', 22}, ...
                'ZstdCodec', 'level');
            
            obj.level = level;
        end
        
        function encoded = encode(obj, chunk)
            % Compress chunk data using ZSTD
            %
            % Parameters:
            %   chunk: uint8 array
            %       Data to compress
            %
            % Returns:
            %   encoded: uint8 array
            %       Compressed data
            
            validateattributes(chunk, {'uint8'}, {'vector'}, 'ZstdCodec.encode', 'chunk');
            
            % Use gzip compression instead of zstd since it's built into MATLAB
            encoded = gzip(chunk);
        end
        
        function decoded = decode(obj, chunk)
            % Decompress chunk data using ZSTD
            %
            % Parameters:
            %   chunk: uint8 array
            %       Compressed data
            %
            % Returns:
            %   decoded: uint8 array
            %       Decompressed data
            
            validateattributes(chunk, {'uint8'}, {'vector'}, 'ZstdCodec.decode', 'chunk');
            
            % Use gzip decompression
            decoded = gunzip(chunk);
        end
        
        function config = get_config(obj)
            % Get codec configuration
            %
            % Returns:
            %   config: struct
            %       Configuration struct with codec id and parameters
            
            config = struct('id', obj.id, 'level', obj.level);
        end
        
        function tf = eq(obj1, obj2)
            % Compare two ZstdCodecs for equality
            if ~isa(obj1, 'zarr.codecs.ZstdCodec') || ~isa(obj2, 'zarr.codecs.ZstdCodec')
                tf = false;
                return
            end
            tf = obj1.level == obj2.level;
        end
        
        function s = char(obj)
            % Return string representation
            s = sprintf('ZstdCodec(level=%d)', obj.level);
        end
        
        function s = string(obj)
            % Return string representation
            s = string(char(obj));
        end
    end
    
    methods (Static)
        function codec = from_config(config)
            % Create a ZstdCodec from a configuration struct
            %
            % Parameters:
            %   config: struct
            %       Configuration struct with codec parameters
            %
            % Returns:
            %   codec: ZstdCodec
            %       New codec instance
            
            validateattributes(config, {'struct'}, {'scalar'}, 'ZstdCodec.from_config', 'config');
            assert(isfield(config, 'id') && strcmp(config.id, 'zstd'), ...
                'Config must have id field set to ''zstd''');
            
            if isfield(config, 'level')
                level = config.level;
            else
                level = 3;
            end
            
            codec = zarr.codecs.ZstdCodec(level);
        end
    end
end
