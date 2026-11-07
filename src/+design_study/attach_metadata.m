function tableOut = attach_metadata(tableIn,metadata)
%ATTACH_METADATA A table with the certification and provenance columns of the design study.
%   TABLEOUT = design_study.attach_metadata(TABLEIN, METADATA) appends to
%   TABLEIN one column per field of design_study.required_metadata_fields,
%   each repeated on every row, from METADATA (design_study.make_metadata);
%   failure reasons are joined with ' | ', logical fields stay logical and
%   the others become text.
%   Side effects: none.
    tableOut = tableIn;
    n = height(tableOut);
    fields = design_study.required_metadata_fields();
    for i = 1:numel(fields)
        name = fields{i};
        value = metadata.(name);
        if strcmp(name,'failure_reasons')
            if ischar(value) || isstring(value), value = cellstr(value); end
            value = strjoin(string(value),' | ');
        end
        if islogical(value)
            column = repmat(value,n,1);
        else
            column = repmat(string(value),n,1);
        end
        tableOut.(name) = column;
    end
end

