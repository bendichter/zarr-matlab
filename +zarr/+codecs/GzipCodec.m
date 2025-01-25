classdef GzipCodec < zarr.codecs.Codec
    % GZIPCODEC Gzip compression codec
    %   Implements gzip compression using MATLAB's built-in gzip functionality
    
    properties
        level = 5  % Compression level (1-9)
    end
    
    methods
        function obj = GzipCodec(level)
            % Create a new GzipCodec
            %
            % Parameters:
            %   level: numeric
            %       Compression level (1-9, default: 5)
            
            if nargin > 0
                if ~isnumeric(level) || level < 1 || level > 9
                    error('zarr:InvalidCompressionLevel', ...
                        'Compression level must be between 1 and 9');
                end
                obj.level = level;
            end
        end
        
        function encoded = encode(obj, data)
            % Encode data using gzip compression
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
            
            % Use MATLAB's built-in gzip
            try
                % Create temporary files
                temp_in = [tempname '.bin'];
                temp_gz = [temp_in '.gz'];
                cleanup = onCleanup(@() delete_if_exists({temp_in, temp_gz}));
                
                % Write data to temp file
                fid = fopen(temp_in, 'wb');
                if fid == -1
                    error('zarr:FileError', 'Failed to open temporary file for writing');
                end
                fwrite(fid, data, 'uint8');
                fclose(fid);
                
                % Compress using gzip
                gzip(temp_in);
                
                % Read compressed data
                fid = fopen(temp_gz, 'rb');
                if fid == -1
                    error('zarr:FileError', 'Failed to open compressed file for reading');
                end
                encoded = fread(fid, inf, 'uint8=>uint8')';
                fclose(fid);
            catch ME
                error('zarr:CompressionError', ...
                    'Gzip compression failed: %s', ME.message);
            end
        end
        
        function decoded = decode(obj, data)
            % Decode gzip compressed data
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
            
            % Use MATLAB's built-in gunzip
            try
                % Create temporary files
                temp_in = [tempname '.bin'];
                temp_gz = [temp_in '.gz'];
                cleanup = onCleanup(@() delete_if_exists({temp_in, temp_gz}));
                
                % Write compressed data
                fid = fopen(temp_gz, 'wb');
                if fid == -1
                    error('zarr:FileError', 'Failed to open temporary file for writing');
                end
                fwrite(fid, data, 'uint8');
                fclose(fid);
                
                % Decompress using gunzip
                gunzip(temp_gz);
                
                % Read decompressed data (gunzip removes .gz extension)
                temp_out = temp_in;
                fid = fopen(temp_out, 'rb');
                if fid == -1
                    error('zarr:FileError', 'Failed to open decompressed file for reading');
                end
                decoded = fread(fid, inf, 'uint8=>uint8')';
                fclose(fid);
            catch ME
                error('zarr:DecompressionError', ...
                    'Gzip decompression failed: %s', ME.message);
            end
        end
        
        function config = get_config(obj)
            % Get codec configuration
            %
            % Returns:
            %   config: struct
            %       Codec configuration
            
            config = struct(...
                'id', 'gzip', ...
                'level', obj.level);
        end
    end
end

function delete_if_exists(files)
    % Helper function to delete temporary files if they exist
    for i = 1:numel(files)
        if exist(files{i}, 'file')
            delete(files{i});
        end
    end
end
