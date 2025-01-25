classdef ZstdCodec < zarr.codecs.Codec
    % ZSTDCODEC Zstandard compression codec
    %   Implements Zstandard compression using the zstd library
    
    properties
        level = 3  % Compression level (-131072 to 22, default: 3)
        checksum = false  % Whether to include checksum in compressed data
    end
    
    methods
        function obj = ZstdCodec(varargin)
            % Create a new ZstdCodec
            %
            % Parameters:
            %   Name-Value Pairs:
            %     'level': numeric
            %         Compression level (-131072 to 22, default: 3)
            %     'checksum': logical
            %         Whether to include checksum (default: false)
            
            p = inputParser;
            addParameter(p, 'level', 3, @isnumeric);
            addParameter(p, 'checksum', false, @islogical);
            parse(p, varargin{:});
            
            % Validate level
            level = p.Results.level;
            if level > 22
                level = 22;
                warning('zarr:zstd:levelAdjusted', ...
                    'Compression level adjusted to maximum value (22)');
            elseif level < -131072
                level = -131072;
                warning('zarr:zstd:levelAdjusted', ...
                    'Compression level adjusted to minimum value (-131072)');
            end
            
            obj.level = level;
            obj.checksum = p.Results.checksum;
        end
        
        function encoded = encode(obj, data)
            % Encode data using zstd compression
            %
            % Parameters:
            %   data: uint8 vector
            %       Data to compress
            %
            % Returns:
            %   encoded: uint8 vector
            %       Compressed data
            
            if ~isa(data, 'uint8')
                error('zarr:InvalidInput', 'Input must be uint8');
            end
            
            % Handle empty array
            if isempty(data)
                encoded = zeros(0, 0, 'uint8');
                return;
            end
            
            % Use MEX function for compression
            encoded = zstdmex(data, obj.level, obj.checksum);
        end
        
        function decoded = decode(obj, data)
            % Decode zstd compressed data
            %
            % Parameters:
            %   data: uint8 vector
            %       Compressed data
            %
            % Returns:
            %   decoded: uint8 vector
            %       Decompressed data
            
            if ~isa(data, 'uint8')
                error('zarr:InvalidInput', 'Input must be uint8');
            end
            
            % Handle empty array
            if isempty(data)
                decoded = zeros(0, 0, 'uint8');
                return;
            end
            
            % Use MEX function for decompression
            decoded = zstddmex(data);
        end
        
        function config = get_config(obj)
            % Get codec configuration
            %
            % Returns:
            %   config: struct
            %       Codec configuration
            
            config = struct(...
                'id', 'zstd', ...
                'level', obj.level, ...
                'checksum', obj.checksum);
        end
        
        function tf = eq(obj, other)
            % Test if two codecs are equal
            %
            % Parameters:
            %   other: ZstdCodec
            %       Codec to compare with
            %
            % Returns:
            %   tf: logical
            %       True if codecs are equal
            
            tf = strcmp(class(obj), class(other)) && ...
                obj.level == other.level && ...
                obj.checksum == other.checksum;
        end
    end
    
    methods (Static)
        function codec = from_config(config)
            % Create codec from configuration
            %
            % Parameters:
            %   config: struct
            %       Codec configuration
            %
            % Returns:
            %   codec: ZstdCodec
            %       New codec instance
            
            if ~isfield(config, 'id') || ~strcmp(config.id, 'zstd')
                error('zarr:InvalidCodecConfig', ...
                    'Configuration is not for zstd codec');
            end
            
            level = 3;  % default
            if isfield(config, 'level')
                level = config.level;
            end
            
            checksum = false;  % default
            if isfield(config, 'checksum')
                checksum = config.checksum;
            end
            
            codec = zarr.codecs.ZstdCodec('level', level, 'checksum', checksum);
        end
    end
end
