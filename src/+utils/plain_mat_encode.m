function S=plain_mat_encode(S)
%PLAIN_MAT_ENCODE The variables of a MAT file in types that open without MATLAB.
%   S = utils.plain_mat_encode(S) takes the scalar struct S of the variables
%   of a MAT file and stores its MATLAB-only types as plain ones, so that
%   any MAT reader (scipy.io.loadmat, h5py) opens the file:
%     a table          a scalar struct with one field per column (the
%                      column names are valid identifiers), its string
%                      columns as cell arrays of character vectors;
%     a string array   a cell array of character vectors of the same size;
%     a struct array   each of its fields that holds a string array in
%                      every element, as such a cell array.
%   The added variable plainMatEncoding lists what was converted, one
%   element per conversion: path (the variable, or variable.field), type
%   ('table' or 'string') and stringColumns (the table's string columns).
%   utils.plain_mat_decode restores the original values exactly
%   (utils.load_plain_mat loads and restores). Other objects (missing
%   strings, categorical, datetime, classdef objects) are refused.
%   Side effects: none.

    assert(isstruct(S)&&isscalar(S)&&~isfield(S,'plainMatEncoding'), ...
        'utils:plain_mat_encode:Input', ...
        'The variables must be one scalar struct without plainMatEncoding.');
    encoding=struct('path',{},'type',{},'stringColumns',{});
    names=fieldnames(S);
    for i=1:numel(names)
        value=S.(names{i});
        if istable(value)
            [S.(names{i}),columns]=encode_table(value,names{i});
            encoding(end+1)=entry(names{i},'table',columns); %#ok<AGROW>
        elseif isstring(value)
            S.(names{i})=encode_string(value,names{i});
            encoding(end+1)=entry(names{i},'string',{}); %#ok<AGROW>
        elseif isstruct(value)
            fields=fieldnames(value);
            for k=1:numel(fields)
                if ~isempty(value)&&all(arrayfun(@(e) isstring(e.(fields{k})),value))
                    for e=1:numel(value)
                        value(e).(fields{k})=encode_string(value(e).(fields{k}), ...
                            sprintf('%s.%s',names{i},fields{k}));
                    end
                    encoding(end+1)=entry(sprintf('%s.%s',names{i},fields{k}),'string',{}); %#ok<AGROW>
                end
            end
            S.(names{i})=value;
        end
        refuse_objects(S.(names{i}),names{i});
    end
    S.plainMatEncoding=encoding;
end

function [s,columns]=encode_table(T,where)
    p=T.Properties;
    assert(isempty(p.RowNames)&&isempty(p.Description)&&isempty(p.UserData)&& ...
        all(cellfun(@isempty,p.VariableUnits))&&all(cellfun(@isempty,p.VariableDescriptions))&& ...
        isequal(p.DimensionNames,{'Row','Variables'})&&isempty(fieldnames(p.CustomProperties))&& ...
        all(cellfun(@isvarname,p.VariableNames)), ...
        'utils:plain_mat_encode:TableProperties', ...
        'The table %s has properties that a plain struct does not keep.',where);
    s=struct();columns={};
    for c=1:width(T)
        name=p.VariableNames{c};
        value=T.(name);
        if isstring(value)
            value=encode_string(value,sprintf('%s.%s',where,name));
            columns{end+1}=name; %#ok<AGROW>
        end
        s.(name)=value;
    end
end

function value=encode_string(value,where)
    assert(~any(ismissing(value),'all'),'utils:plain_mat_encode:MissingString', ...
        'The string array %s holds missing values, which a cell of text does not keep.',where);
    value=cellstr(value);
end

function e=entry(pathValue,type,columns)
    e=struct('path',pathValue,'type',type,'stringColumns',{reshape(columns,1,[])});
end

function refuse_objects(value,where)
%REFUSE_OBJECTS Every value left must be numeric, logical, text (char, cell of char) or a struct of them.
    if isstruct(value)
        fields=fieldnames(value);
        for e=1:numel(value)
            for k=1:numel(fields)
                refuse_objects(value(e).(fields{k}),sprintf('%s.%s',where,fields{k}));
            end
        end
    elseif iscell(value)
        for k=1:numel(value)
            refuse_objects(value{k},where);
        end
    else
        assert(isnumeric(value)||islogical(value)||ischar(value), ...
            'utils:plain_mat_encode:Type', ...
            'The value %s is of class %s, which only MATLAB reads.',where,class(value));
    end
end
