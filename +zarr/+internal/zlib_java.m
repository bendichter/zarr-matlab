function out = zlib_java(mode, bytes, level)
%ZLIB_JAVA zlib (RFC 1950) compress/decompress via java.util.zip.
%   out = zlib_java('compress', bytes, level)
%   out = zlib_java('decompress', bytes)
%   This is the framing HDF5's deflate filter and numcodecs' Zlib use
%   (2-byte header + adler32), unlike the gzip wrapper in gzip_java.

bytes = uint8(bytes(:)');
switch mode
    case 'compress'
        deflater = java.util.zip.Deflater(level, false);  % zlib framing
        baos = java.io.ByteArrayOutputStream();
        dos = java.util.zip.DeflaterOutputStream(baos, deflater);
        if ~isempty(bytes)
            dos.write(typecast(bytes, 'int8'));
        end
        dos.close();
        javaMethod('end', deflater);
        out = typecast(int8(baos.toByteArray())', 'uint8');
    case 'decompress'
        inflater = java.util.zip.Inflater(false);
        baos = java.io.ByteArrayOutputStream();
        ios = java.util.zip.InflaterOutputStream(baos, inflater);
        try
            if ~isempty(bytes)
                ios.write(typecast(bytes, 'int8'));
            end
            ios.close();
        catch
            javaMethod('end', inflater);
            error("zarr:CodecError", "zlib: invalid or corrupt stream.");
        end
        javaMethod('end', inflater);
        out = typecast(int8(baos.toByteArray())', 'uint8');
    otherwise
        error("zarr:InternalError", "Unknown zlib_java mode '%s'.", mode);
end
end
