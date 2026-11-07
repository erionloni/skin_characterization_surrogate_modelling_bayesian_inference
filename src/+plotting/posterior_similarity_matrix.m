function [values,cases] = posterior_similarity_matrix(T,caseOrder)
%POSTERIOR_SIMILARITY_MATRIX Read a saved axis/subspace similarity table.
%   Supports the canonical wide CaseID matrix and a normalized long format.
%   A CaseID-only zero-row table is a valid empty cohort, not a schema error.
%   [VALUES, CASES] = plotting.posterior_similarity_matrix(T, CASEORDER)
%   returns the case-by-case similarity matrix in the order CASEORDER and
%   the cases it covers.
%   Side effects: none.

    assert(istable(T), ...
        'plotting:posterior_similarity_matrix:InputType', ...
        'The similarity input must be a table.');
    caseOrder=reshape(double(caseOrder),1,[]);
    names=string(T.Properties.VariableNames);
    if ismember("CaseID",names)
        if isempty(T)||width(T)==1
            values=zeros(0);cases=zeros(1,0);return
        end
        tableCases=double(T.CaseID);
        valueColumns=setdiff(1:width(T),find(names=="CaseID",1),'stable');
        raw=double(T{:,valueColumns});
        assert(size(raw,1)==numel(tableCases)&& ...
            size(raw,2)==numel(tableCases), ...
            'plotting:posterior_similarity_matrix:WideShape', ...
            'A wide similarity table must contain one Case_<ID> column per row.');
        cases=intersect(caseOrder,tableCases,'stable');
        [present,locations]=ismember(cases,tableCases);
        assert(all(present), ...
            'plotting:posterior_similarity_matrix:CaseOrder', ...
            'Internal error: a case of the similarity table was not found in it.');
        values=raw(locations,locations);
    elseif all(ismember(["RowCaseID" "ColumnCaseID" "Similarity"],names))
        [values,cases]=long_matrix(T,'RowCaseID','ColumnCaseID',caseOrder);
    elseif all(ismember(["CaseIDRow" "CaseIDColumn" "Similarity"],names))
        [values,cases]=long_matrix(T,'CaseIDRow','CaseIDColumn',caseOrder);
    else
        error('plotting:posterior_similarity_matrix:Schema', ...
            ['Similarity tables must be a wide CaseID matrix or use ' ...
             'RowCaseID, ColumnCaseID, Similarity fields.']);
    end
end

function [values,cases]=long_matrix(T,rowName,columnName,caseOrder)
    rowIDs=double(T.(rowName));columnIDs=double(T.(columnName));
    cases=intersect(caseOrder,unique([rowIDs;columnIDs],'stable'),'stable');
    values=nan(numel(cases));
    for i=1:height(T)
        r=find(cases==rowIDs(i),1);c=find(cases==columnIDs(i),1);
        if ~isempty(r)&&~isempty(c),values(r,c)=double(T.Similarity(i));end
    end
end
