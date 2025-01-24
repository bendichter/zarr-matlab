classdef BloscCodec < handle
    % BLOSCCODEC Blosc compression codec for Zarr arrays
    %   Implements Blosc compression with configurable compressor, compression
    %   level, and shuffle filter. Supports Python Zarr's default settings.
    
    properties (SetAccess = private)
        cname       % Compressor name ('zstd', 'lz4', or 'zlib')
        clevel      % Compression level (1-9)
        shuffle     % Whether to use shuffle filter (true/false)
        blocksize   % Block size (0 for auto)
    end
    
    methods (Access = public)
        function obj = BloscCodec(varargin)
            % Create a new BloscCodec instance
            %
            % Parameters (name-value pairs):
            %   'cname': string
            %       Compressor name ('zstd', 'lz4', or 'zlib', default: 'zstd')
            %   'clevel': numeric
            %       Compression level (1-9, default: 5)
            %   'shuffle': logical
            %       Whether to use shuffle filter (default: true)
            %   'blocksize': numeric
            %       Block size (0 for auto, default: 0)
            
            try
                % Parse inputs
                p = inputParser;
                p.addParameter('cname', 'zstd', @(x) ismember(x, {'zstd', 'lz4', 'zlib'}));
                p.addParameter('clevel', 5, @(x) isnumeric(x) && isscalar(x) && ...
                    x >= 1 && x <= 9 && mod(x, 1) == 0);
                p.addParameter('shuffle', true, @islogical);
                p.addParameter('blocksize', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
                
                p.parse(varargin{:});
                
                % Store properties
                obj.cname = p.Results.cname;
                obj.clevel = p.Results.clevel;
                obj.shuffle = p.Results.shuffle;
                obj.blocksize = p.Results.blocksize;
            catch ME
                throw(zarr.errors.CodecError(...
                    sprintf('Invalid codec parameters: %s', ME.message)));
            end
        end
        
        function config = get_config(obj)
            % Get codec configuration for metadata
            %
            % Returns:
            %   config: struct
            %       Configuration struct for Zarr metadata
            
            config = struct(...
                'id', 'blosc', ...
                'cname', obj.cname, ...
                'clevel', obj.clevel, ...
                'shuffle', obj.shuffle, ...
                'blocksize', obj.blocksize);
        end
        
        function compressed = encode(obj, data)
            % Compress data using Blosc
            %
            % Parameters:
            %   data: uint8 vector
            %       Data to compress
            %
            % Returns:
            %   compressed: uint8 vector
            %       Compressed data
            
            % Validate input
            validateattributes(data, {'uint8'}, {'vector'});
            
            try
                % Call Blosc compression
                compressed = blosc_compress(data, ...
                    'compressor', obj.cname, ...
                    'level', obj.clevel, ...
                    'shuffle', obj.shuffle, ...
                    'blocksize', obj.blocksize);
            catch ME
                throw(zarr.errors.CodecError(...
                    sprintf('Blosc compression failed: %s', ME.message)));
            end
        end
        
        function decompressed = decode(obj, data)
            % Decompress data using Blosc
            %
            % Parameters:
            %   data: uint8 vector
            %       Compressed data
            %
            % Returns:
            %   decompressed: uint8 vector
            %       Decompressed data
            
            % Validate input
            validateattributes(data, {'uint8'}, {'vector'});
            
            try
                % Call Blosc decompression
                decompressed = blosc_decompress(data);
            catch ME
                throw(zarr.errors.CodecError(...
                    sprintf('Blosc decompression failed: %s', ME.message)));
            end
        end
        
        function tf = eq(obj, other)
            % Compare BloscCodec instances for equality
            %
            % Parameters:
            %   other: BloscCodec
            %       Codec to compare with
            %
            % Returns:
            %   tf: logical
            %       True if codecs have identical settings
            
            tf = isa(other, 'zarr.codecs.BloscCodec') && ...
                strcmp(obj.cname, other.cname) && ...
                obj.clevel == other.clevel && ...
                obj.shuffle == other.shuffle && ...
                obj.blocksize == other.blocksize;
        end
        
        function str = char(obj)
            % Convert codec to string representation
            %
            % Returns:
            %   str: string
            %       String description of codec settings
            
            str = sprintf('blosc(cname=%s, clevel=%d, shuffle=%d)', ...
                obj.cname, obj.clevel, obj.shuffle);
        end
    end
    
    methods (Static, Access = public)
        function codec = from_config(config)
            % Create codec from configuration struct
            %
            % Parameters:
            %   config: struct
            %       Configuration struct from metadata
            %
            % Returns:
            %   codec: BloscCodec
            %       New codec instance
            
            % Validate config
            if ~isfield(config, 'id') || ~strcmp(config.id, 'blosc')
                throw(zarr.errors.CodecError('Invalid codec configuration: missing or incorrect id'));
            end
            
            % Validate required fields
            required_fields = {'cname', 'clevel', 'shuffle', 'blocksize'};
            for i = 1:numel(required_fields)
                if ~isfield(config, required_fields{i})
                    throw(zarr.errors.CodecError(...
                        sprintf('Invalid codec configuration: missing field %s', ...
                        required_fields{i})));
                end
            end
            
            % Create codec with settings from config
            codec = zarr.codecs.BloscCodec(...
                'cname', config.cname, ...
                'clevel', config.clevel, ...
                'shuffle', config.shuffle, ...
                'blocksize', config.blocksize);
        end
    end
end
