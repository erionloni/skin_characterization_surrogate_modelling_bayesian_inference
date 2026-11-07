function T=read_csv_table(pathValue,textColumns,varargin)
%READ_CSV_TABLE Read a comma-separated table with the named columns as text.
%   T = utils.read_csv_table(PATH, TEXTCOLUMNS) reads the CSV file PATH with
%   a comma delimiter, and the columns named in TEXTCOLUMNS (cellstr or
%   string array; names the file lacks are ignored) as strings, with empty
%   fields as "". Other columns are typed by detection, text as strings.
%   Without the declaration, detection reads a text column that is empty in
%   every row (no failure reason, no condition code) as numbers, and text
%   operations on it fail.
%   T = utils.read_csv_table(..., Name, Value) passes further options to
%   detectImportOptions, e.g. 'VariableNamingRule','preserve'.
%   Side effects: none.
    options=detectImportOptions(pathValue,'Delimiter',',','TextType','string', ...
        varargin{:});
    textColumns=intersect(options.VariableNames,cellstr(string(textColumns)),'stable');
    options=setvartype(options,textColumns,'string');
    T=readtable(pathValue,options);
    for i=1:numel(textColumns)
        column=T.(textColumns{i});
        column(ismissing(column))="";
        T.(textColumns{i})=column;
    end
end
