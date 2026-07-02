function out = gzip_java(mode, bytes, level)
%GZIP_JAVA Gzip (RFC 1952) compress/decompress via java.util.zip.
%   out = gzip_java('compress', bytes, level)
%   out = gzip_java('decompress', bytes)
%
%   Uses Deflater/InflaterOutputStream so data only ever flows MATLAB -> Java
%   (Java-filled byte buffers are not visible to MATLAB).

bytes = uint8(bytes(:)');
switch mode
    case 'compress'
        deflater = java.util.zip.Deflater(level, true);  % raw deflate
        baos = java.io.ByteArrayOutputStream();
        dos = java.util.zip.DeflaterOutputStream(baos, deflater);
        if ~isempty(bytes)
            dos.write(typecast(bytes, 'int8'));
        end
        dos.close();
        javaMethod('end', deflater);
        raw = typecast(int8(baos.toByteArray())', 'uint8');

        crcObj = java.util.zip.CRC32();
        if ~isempty(bytes)
            crcObj.update(typecast(bytes, 'int8'));
        end
        crc = typecast(uint32(crcObj.getValue()), 'uint8');
        isize = typecast(uint32(mod(numel(bytes), 2^32)), 'uint8');
        % Header: magic, CM=deflate, no flags, mtime 0, XFL 0, OS 255 (unknown).
        header = uint8([31 139 8 0 0 0 0 0 0 255]);
        out = [header, raw, crc, isize];

    case 'decompress'
        n = numel(bytes);
        if n < 18 || bytes(1) ~= 31 || bytes(2) ~= 139 || bytes(3) ~= 8
            error("zarr:CodecError", "Invalid gzip stream.");
        end
        flg = bytes(4);
        pos = 11;  % first byte after the fixed 10-byte header (1-based)
        if bitand(flg, 4)  % FEXTRA
            xlen = double(bytes(pos)) + 256 * double(bytes(pos + 1));
            pos = pos + 2 + xlen;
        end
        if bitand(flg, 8)  % FNAME: zero-terminated
            pos = find(bytes(pos:end) == 0, 1) + pos;
        end
        if bitand(flg, 16)  % FCOMMENT
            pos = find(bytes(pos:end) == 0, 1) + pos;
        end
        if bitand(flg, 2)  % FHCRC
            pos = pos + 2;
        end
        raw = bytes(pos:n - 8);

        inflater = java.util.zip.Inflater(true);
        baos = java.io.ByteArrayOutputStream();
        ios = java.util.zip.InflaterOutputStream(baos, inflater);
        if ~isempty(raw)
            ios.write(typecast(raw, 'int8'));
        end
        ios.close();
        javaMethod('end', inflater);
        out = typecast(int8(baos.toByteArray())', 'uint8');

        expectedCrc = typecast(bytes(n - 7:n - 4), 'uint32');
        crcObj = java.util.zip.CRC32();
        if ~isempty(out)
            crcObj.update(typecast(out, 'int8'));
        end
        if uint32(crcObj.getValue()) ~= expectedCrc
            error("zarr:CodecError", "Gzip CRC mismatch: corrupt data.");
        end

    otherwise
        error("zarr:InternalError", "Unknown gzip_java mode '%s'.", mode);
end
end
