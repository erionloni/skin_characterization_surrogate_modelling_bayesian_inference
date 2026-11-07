function T = read_exact_table(pathValue, numeric)
%READ_EXACT_TABLE A confirmation table read with its numbers exact.
%   T = confirmation.read_exact_table(PATH, NUMERIC) reads the CSV file PATH
%   with every column as text (empty fields as "") and the columns NUMERIC
%   (those the file has) as doubles: text written with 17 significant
%   digits gives back the double it was written from, an empty field NaN.
%   Column names are kept as written.
%   Side effects: none.
    options = detectImportOptions(pathValue, 'Delimiter', ',', 'TextType', 'string', ...
        'VariableNamingRule', 'preserve');
    options = setvartype(options, 'string');
    options = setvaropts(options, 'FillValue', "");
    T = readtable(pathValue, options);
    numeric = intersect(cellstr(numeric), T.Properties.VariableNames, 'stable');
    for k = 1:numel(numeric)
        T.(numeric{k}) = str2double(T.(numeric{k}));
    end
end
