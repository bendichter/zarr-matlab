function [keys, values] = json_object_entries(txt)
%JSON_OBJECT_ENTRIES Top-level key/value pairs of a JSON object, as raw text.
%   jsondecode mangles keys into valid struct field names (breaking node
%   paths like "sub/named"); this tokenizer preserves keys exactly and
%   returns each value's exact source text.

txt = char(txt);
n = numel(txt);
pos = skipWs(txt, 1);
if pos > n || txt(pos) ~= '{'
    error("zarr:InvalidMetadata", "Expected a JSON object.");
end
pos = skipWs(txt, pos + 1);
keys = strings(0, 1);
values = strings(0, 1);
if pos <= n && txt(pos) == '}'
    return
end
while true
    [key, pos] = parseString(txt, pos);
    pos = skipWs(txt, pos);
    if pos > n || txt(pos) ~= ':'
        error("zarr:InvalidMetadata", "Malformed JSON object (expected ':').");
    end
    pos = skipWs(txt, pos + 1);
    [valueText, pos] = parseValue(txt, pos);
    keys(end + 1, 1) = key; %#ok<AGROW>
    values(end + 1, 1) = valueText; %#ok<AGROW>
    pos = skipWs(txt, pos);
    if pos > n
        error("zarr:InvalidMetadata", "Unterminated JSON object.");
    end
    if txt(pos) == ','
        pos = skipWs(txt, pos + 1);
    elseif txt(pos) == '}'
        return
    else
        error("zarr:InvalidMetadata", "Malformed JSON object.");
    end
end
end

function pos = skipWs(txt, pos)
n = numel(txt);
while pos <= n && any(txt(pos) == sprintf(' \t\r\n'))
    pos = pos + 1;
end
end

function [s, pos] = parseString(txt, pos)
%Parse a JSON string starting at txt(pos) == '"'; returns the UNESCAPED value.
if txt(pos) ~= '"'
    error("zarr:InvalidMetadata", "Expected a JSON string key.");
end
i = pos + 1;
n = numel(txt);
while i <= n
    if txt(i) == '\'
        i = i + 2;
    elseif txt(i) == '"'
        raw = txt(pos:i);
        s = string(jsondecode(raw));  % delegate unescaping
        pos = i + 1;
        return
    else
        i = i + 1;
    end
end
error("zarr:InvalidMetadata", "Unterminated JSON string.");
end

function [valueText, pos] = parseValue(txt, pos)
n = numel(txt);
start = pos;
switch txt(pos)
    case {'{', '['}
        open = txt(pos);
        if open == '{', close = '}'; else, close = ']'; end
        depth = 0;
        i = pos;
        while i <= n
            c = txt(i);
            if c == '"'
                [~, i] = parseString(txt, i);
                continue
            elseif c == open
                depth = depth + 1;
            elseif c == close
                depth = depth - 1;
                if depth == 0
                    valueText = string(txt(start:i));
                    pos = i + 1;
                    return
                end
            end
            i = i + 1;
        end
        error("zarr:InvalidMetadata", "Unterminated JSON value.");
    case '"'
        [~, pos] = parseString(txt, pos);
        valueText = string(txt(start:pos - 1));
    otherwise  % number / true / false / null
        i = pos;
        while i <= n && ~any(txt(i) == ',}] ') && txt(i) ~= sprintf('\n')
            i = i + 1;
        end
        valueText = string(strtrim(txt(start:i - 1)));
        pos = i;
end
end
