function contract = final_data_contract(caseIDs,sourceRows,X,Y,varargin)
%FINAL_DATA_CONTRACT Classify, group and split six-output material evidence.
%   CONTRACT = data.final_data_contract(CASEIDS, SOURCEROWS, X, Y, ...) takes
%   one row per source observation (CASEIDS and SOURCEROWS: N-by-1; X:
%   N-by-M inputs; Y: N-by-6 closing pressures in mbar, NaN where not
%   observed) and returns the data contract shared by both routes:
%     - rows with equal inputs form one duplicate group (labelled V0001,
%       V0002, ... in the order of their first row) and are consolidated
%       when their finite outputs agree; conflicting duplicates are kept in
%       the audit as unusable;
%     - each case is complete (six finite outputs), partial or unusable;
%       missing outputs stay NaN and are never imputed;
%     - complete cases are split, by split group, into development and
%       external-test roles with the seed 'SplitSeed' and the fraction
%       'TestFraction' (round(fraction * complete cases)); 'RequiredExternal
%       CaseIDs' must end up external; partial cases are development only;
%     - per output, the development cases that observed it (its training
%       evidence).
%   Options: 'InputNames', 'OutputNames', 'SplitSeed', 'TestFraction' and
%   'SplitGroupIdentities' (the last three required: the settings' master
%   seed and external fraction, and one split group label per row; rows
%   with equal inputs must share one), 'SplitAlgorithmVersion',
%   'RequiredExternalCaseIDs', 'PreferredExternalCaseIDs'.
%   CONTRACT: the case manifest, the excluded rows, the source map, X_all
%   and Y_all, the output availability mask, the development and external
%   indices and CaseIDs, the per-output evidence, the availability
%   patterns and the counts.
%   Side effects: none (the split seeds the random number generator and
%   restores its state afterwards).

    parser=inputParser;
    parser.FunctionName='data.final_data_contract';
    addParameter(parser,'InputNames',{},@cell_text);
    addParameter(parser,'OutputNames',{},@cell_text);
    addParameter(parser,'SplitSeed',[],@(x)isempty(x)||positive_integer(x));
    addParameter(parser,'TestFraction',[],@(x)isempty(x)||fraction(x));
    addParameter(parser,'SplitAlgorithmVersion', ...
        'complete_case_constrained_mt19937_v2',@text_scalar);
    addParameter(parser,'RequiredExternalCaseIDs',[],@case_vector);
    addParameter(parser,'PreferredExternalCaseIDs',[],@case_vector);
    addParameter(parser,'SplitGroupIdentities',[],@split_group_vector);
    parse(parser,varargin{:});
    options=parser.Results;
    assert(~isempty(options.SplitSeed)&&~isempty(options.TestFraction)&& ...
        ~isempty(options.SplitGroupIdentities), ...
        'data:final_data_contract:Split', ...
        ['The split needs its seed, external fraction and split groups ' ...
         '(''SplitSeed'', ''TestFraction'', ''SplitGroupIdentities'').']);

    caseIDs=double(caseIDs(:));sourceRows=double(sourceRows(:));
    X=double(X);Y=double(Y);
    assert(size(X,1)==numel(caseIDs)&&size(Y,1)==numel(caseIDs)&& ...
        numel(sourceRows)==numel(caseIDs)&&size(Y,2)==6&& ...
        all(isfinite(sourceRows))&&all(sourceRows==fix(sourceRows))&& ...
        numel(unique(sourceRows))==numel(sourceRows), ...
        'data:final_data_contract:Shape', ...
        'CaseID, source-row, input and six-output row counts must agree.');
    inputNames=cellstr(string(options.InputNames(:))).';
    outputNames=cellstr(string(options.OutputNames(:))).';
    if isempty(inputNames),inputNames=compose('Input%d',1:size(X,2));end
    if isempty(outputNames),outputNames=compose('Output%d',1:6);end
    assert(numel(inputNames)==size(X,2)&&numel(outputNames)==6, ...
        'data:final_data_contract:Names', ...
        'Input names must match X and exactly six output names are required.');
    splitGroups=normalize_split_groups(options.SplitGroupIdentities);
    assert(numel(splitGroups)==numel(caseIDs), ...
        'data:final_data_contract:SplitGroupShape', ...
        'SplitGroupIdentities must contain one value per source row.');

    required=reshape(double(options.RequiredExternalCaseIDs),1,[]);
    preferred=reshape(double(options.PreferredExternalCaseIDs),1,[]);
    assert(numel(unique(required))==numel(required)&& ...
        numel(unique(preferred))==numel(preferred), ...
        'data:final_data_contract:ExternalCaseIDs', ...
        'Required and preferred external CaseID lists must be unique.');

    [records,sourceMap]=group_records(caseIDs,sourceRows,X,Y,splitGroups, ...
        required,preferred,inputNames,outputNames);
    eligible=records.Classification~="unusable";
    U=records(eligible,:);
    assert(~isempty(U)&&numel(unique(U.CaseID))==height(U), ...
        'data:final_data_contract:UsableCases', ...
        'At least two uniquely identified usable material cases are required.');
    complete=U.Classification=="complete";
    partial=U.Classification=="partial";
    assert(nnz(complete)>=2,'data:final_data_contract:CompleteCases', ...
        'At least two complete six-output cases are required for an 80/20 split.');

    completeIDs=double(U.CaseID(complete));
    nComplete=numel(completeIDs);
    nExternal=min(max(1,round(double(options.TestFraction)*nComplete)), ...
        nComplete-1);
    assert(all(ismember(required,completeIDs)), ...
        'data:final_data_contract:RequiredExternalIncomplete', ...
        'Every required external CaseID must identify a complete case.');
    assert(numel(required)<=nExternal, ...
        'data:final_data_contract:RequiredExternalCapacity', ...
        'The complete-case test cohort is smaller than the required anchors.');

    [selected,selectedSplitGroups]=select_external_cases(U,complete,partial, ...
        required,preferred,nExternal,double(options.SplitSeed));
    assert(numel(selected)==nExternal&&numel(unique(selected))==nExternal, ...
        'data:final_data_contract:ExternalSelection', ...
        'The deterministic external selection has the wrong size or duplicates.');

    external=complete&ismember(double(U.CaseID),selected);
    development=~external; % includes every partial case
    U.MethodologicalRole=repmat("development",height(U),1);
    U.MethodologicalRole(external)="external_test";
    U.SplitSeed=repmat(double(options.SplitSeed),height(U),1);
    U.SplitAlgorithmVersion=repmat(string(options.SplitAlgorithmVersion), ...
        height(U),1);
    U.RequiredExternalAnchor=ismember(double(U.CaseID),required);

    availability=logical(U{:,availability_variables()});
    U.AvailabilityPattern=availability_pattern_rows(availability);
    Xall=U{:,inputNames};Yall=U{:,outputNames};
    dev=find(development);test=find(external);
    perOutput=output_evidence(U,Xall,Yall,development,complete,partial, ...
        outputNames);
    patterns=availability_patterns(U,availability);
    counts=struct( ...
        'totalUniqueCases',height(records), ...
        'usableCases',height(U), ...
        'completeCases',nnz(complete), ...
        'partialCases',nnz(partial), ...
        'unusableCases',nnz(records.Classification=="unusable"), ...
        'completeDevelopmentCases',nnz(complete&development), ...
        'partialDevelopmentCases',nnz(partial&development), ...
        'developmentCases',nnz(development), ...
        'externalTestCases',nnz(external), ...
        'perOutputObservedDevelopment',reshape([perOutput.trainingCount],1,[]));

    contract=struct( ...
        'schemaVersion','routeR_final_data_contract_v1', ...
        'caseManifest',U, ...
        'excludedManifest',records(~eligible,:), ...
        'sourceMap',sourceMap, ...
        'X_all',Xall,'Y_all',Yall, ...
        'outputAvailabilityMask',availability, ...
        'selectedExternalSplitGroups',{cellstr(selectedSplitGroups)}, ...
        'splitSeed',double(options.SplitSeed), ...
        'splitAlgorithmVersion',char(string(options.SplitAlgorithmVersion)), ...
        'testFraction',double(options.TestFraction), ...
        'integerRule','round(test_fraction*N_complete)', ...
        'developmentIndices',dev,'externalTestIndices',test, ...
        'developmentCaseIDs',double(U.CaseID(dev)), ...
        'externalTestCaseIDs',double(U.CaseID(test)), ...
        'completeCaseIDs',double(U.CaseID(complete)), ...
        'partialCaseIDs',double(U.CaseID(partial)), ...
        'realizedRequiredExternalCaseIDs',required, ...
        'perOutput',{perOutput},'availabilityPatterns',patterns, ...
        'counts',counts,'inputNames',{inputNames},'outputNames',{outputNames});
end

function [R,sourceMap]=group_records(caseIDs,sourceRows,X,Y,splitGroups, ...
        required,preferred,inputNames,outputNames)
    % Rows with equal inputs are one duplicate group: V0001, V0002, ... in
    % the order of their first row (only the partition is used).
    validInputs=all(isfinite(X),2);
    keys="invalid_source_row_"+string(sourceRows);
    [~,~,vector]=unique(X(validInputs,:),'rows','stable');
    keys(validInputs)=compose("V%04d",vector);
    [uniqueKeys,~,groupIndex]=unique(keys,'stable');
    template=empty_record(size(X,2));
    rows=repmat(template,numel(uniqueKeys),1);
    duplicateCaseConflict=false(numel(uniqueKeys),1);
    validCase=isfinite(caseIDs)&caseIDs==fix(caseIDs);
    for id=unique(caseIDs(validCase)).'
        g=unique(groupIndex(caseIDs==id));
        if numel(g)>1,duplicateCaseConflict(g)=true;end
    end
    sourceParts=cell(numel(uniqueKeys),1);
    for g=1:numel(uniqueKeys)
        idx=find(groupIndex==g);sourceParts{g}=sourceRows(idx);
        one=template;
        one.SourceRow=min(sourceRows(idx));
        one.SourceRows=strjoin(string(sourceRows(idx).'),';');
        aliases=caseIDs(idx);aliases=aliases(isfinite(aliases)&aliases==fix(aliases));
        aliases=unique(aliases,'stable');
        one.CaseIDAliases=strjoin(string(aliases.'),';');
        one.DuplicateGroup=uniqueKeys(g);
        groupValues=unique(splitGroups(idx),'stable');
        one.SplitGroup=groupValues(1);
        one.DuplicateSourceCount=numel(idx);
        one.Classification="unusable";one.ExclusionReason="";
        if numel(groupValues)~=1
            one.ExclusionReason="conflicting_split_group_identity";
        elseif ~all(validInputs(idx))
            one.ExclusionReason="invalid_or_missing_material_input";
        elseif isempty(aliases)
            one.ExclusionReason="missing_or_invalid_case_id";
        elseif duplicateCaseConflict(g)
            one.ExclusionReason="case_id_maps_to_conflicting_material_vectors";
        else
            priority=[required preferred];
            hit=priority(ismember(priority,aliases));
            if isempty(hit),one.CaseID=aliases(1);else,one.CaseID=hit(1);end
            one.X=X(idx(1),:);
            conflict=false;merged=nan(1,6);
            for j=1:6
                values=Y(idx,j);values=values(isfinite(values));
                if isempty(values),continue;end
                if any(values~=values(1)),conflict=true;break;end
                merged(j)=values(1);
            end
            if conflict
                one.ExclusionReason="conflicting_duplicate_output_evidence";
            elseif ~any(isfinite(merged))
                one.ExclusionReason="no_valid_closing_pressure_output";
            else
                one.Y=merged;
                if all(isfinite(merged)),one.Classification="complete";
                else,one.Classification="partial";end
            end
        end
        rows(g)=one;
    end
    [~,order]=sort([rows.SourceRow]);rows=rows(order);sourceParts=sourceParts(order);
    R=records_table(rows,inputNames,outputNames);
    total=sum(cellfun(@numel,sourceParts));
    SourceRow=zeros(total,1);CaseID=nan(total,1);
    DuplicateGroup=strings(total,1);SplitGroup=strings(total,1);
    cursor=0;
    for i=1:numel(rows)
        values=sourceParts{i};positions=cursor+(1:numel(values));cursor=cursor+numel(values);
        SourceRow(positions)=values(:);
        CaseID(positions)=rows(i).CaseID;
        DuplicateGroup(positions)=rows(i).DuplicateGroup;
        SplitGroup(positions)=rows(i).SplitGroup;
    end
    sourceMap=table(SourceRow,CaseID,DuplicateGroup,SplitGroup);
end

function value=empty_record(nInput)
    value=struct('CaseID',NaN,'SourceRow',NaN,'SourceRows',"", ...
        'CaseIDAliases',"",'DuplicateGroup',"",'SplitGroup',"", ...
        'DuplicateSourceCount',0,'Classification',"unusable", ...
        'ExclusionReason',"",'X',nan(1,nInput),'Y',nan(1,6));
end

function T=records_table(rows,inputNames,outputNames)
    nInput=numel(inputNames);
    n=numel(rows);
    CaseID=reshape([rows.CaseID],[],1);SourceRow=reshape([rows.SourceRow],[],1);
    SourceRows=reshape(string({rows.SourceRows}),[],1);
    CaseIDAliases=reshape(string({rows.CaseIDAliases}),[],1);
    DuplicateGroup=reshape(string({rows.DuplicateGroup}),[],1);
    SplitGroup=reshape(string({rows.SplitGroup}),[],1);
    DuplicateSourceCount=reshape([rows.DuplicateSourceCount],[],1);
    Classification=reshape(string({rows.Classification}),[],1);
    ExclusionReason=reshape(string({rows.ExclusionReason}),[],1);
    X=reshape([rows.X],nInput,n).';Y=reshape([rows.Y],6,n).';
    T=table(CaseID,SourceRow,SourceRows,CaseIDAliases, ...
        DuplicateGroup,SplitGroup,DuplicateSourceCount, ...
        Classification,ExclusionReason);
    for j=1:nInput,T.(inputNames{j})=X(:,j);end
    for j=1:6
        T.(outputNames{j})=Y(:,j);
        T.(sprintf('Output%dAvailable',j))=isfinite(Y(:,j));
    end
end

function names=availability_variables()
    names=compose('Output%dAvailable',1:6);
end

function evidence=output_evidence(U,X,Y,development,complete,partial,outputNames)
    evidenceCells=cell(1,6);
    for j=1:6
        mask=development&isfinite(Y(:,j));ids=double(U.CaseID(mask));
        ranges=nan(size(X,2),2);
        if any(mask),ranges=[min(X(mask,:),[],1).' max(X(mask,:),[],1).'];end
        evidenceCells{j}=struct('outputIndex',j,'outputName',outputNames{j}, ...
            'trainingCount',nnz(mask),'trainingCaseIDs',ids, ...
            'trainingMaterialGroupIdentities',U.DuplicateGroup(mask), ...
            'trainingSplitGroupIdentities',U.SplitGroup(mask), ...
            'unavailableDevelopmentCount',nnz(development&~isfinite(Y(:,j))), ...
            'completeContributorCount',nnz(mask&complete), ...
            'partialContributorCount',nnz(mask&partial), ...
            'inputSupportMinMax',ranges);
    end
    evidence=[evidenceCells{:}];
end

function T=availability_patterns(U,mask)
    pattern=availability_pattern_rows(mask);
    values=unique(pattern,'stable');Count=zeros(numel(values),1);
    CompleteCount=zeros(numel(values),1);PartialCount=zeros(numel(values),1);
    for i=1:numel(values)
        rows=pattern==values(i);Count(i)=nnz(rows);
        CompleteCount(i)=nnz(rows&U.Classification=="complete");
        PartialCount(i)=nnz(rows&U.Classification=="partial");
    end
    AvailabilityPattern=values;
    T=table(AvailabilityPattern,Count,CompleteCount,PartialCount);
end

function pattern=availability_pattern_rows(mask)
    pattern=strings(size(mask,1),1);
    for i=1:size(mask,1)
        pattern(i)=join(string(double(mask(i,:))),"");
    end
end

function [selected,selectedGroups]=select_external_cases(U,complete,partial, ...
        required,preferred,nExternal,seed)
%SELECT_EXTERNAL_CASES Choose complete rows without splitting a material group.
%   A group containing any partial development evidence is never eligible for
%   the external test. The deterministic subset solver requires the documented
%   rounded test size to be attainable without splitting a group.
    group=string(U.SplitGroup);
    partialGroups=unique(group(partial),'stable');
    eligible=complete&~ismember(group,partialGroups);
    requiredRows=ismember(double(U.CaseID),required);
    assert(all(eligible(requiredRows)), ...
        'data:final_data_contract:RequiredExternalGroupIneligible', ...
        ['A required external anchor belongs to a split group containing ' ...
         'partial or unusable evidence.']);
    requiredGroups=unique(group(requiredRows),'stable');
    forced=complete&ismember(group,requiredGroups);
    forcedCount=nnz(forced);
    assert(forcedCount<=nExternal, ...
        'data:final_data_contract:RequiredExternalGroupCapacity', ...
        'Required external material groups exceed the rounded test size.');

    candidateGroups=unique(group(eligible&~ismember(group,requiredGroups)), ...
        'stable');
    preferredGroups=strings(numel(preferred),1);preferredCount=0;
    for caseID=preferred
        hit=find(double(U.CaseID)==caseID&eligible,1);
        if ~isempty(hit)&&~ismember(group(hit),requiredGroups)&& ...
                ~ismember(group(hit),preferredGroups(1:preferredCount))
            preferredCount=preferredCount+1;
            preferredGroups(preferredCount)=group(hit);
        end
    end
    preferredGroups=preferredGroups(1:preferredCount);
    otherGroups=candidateGroups(~ismember(candidateGroups,preferredGroups));
    if ~isempty(otherGroups)
        state=rng;restore=onCleanup(@()rng(state));
        rng(seed,'twister');otherGroups=otherGroups(randperm(numel(otherGroups)));
    end
    ordered=[preferredGroups;otherGroups(:)];
    sizes=zeros(numel(ordered),1);
    for i=1:numel(ordered),sizes(i)=nnz(complete&group==ordered(i));end
    chosen=exact_group_subset(sizes,nExternal-forcedCount);
    assert(~isempty(chosen)||(nExternal==forcedCount), ...
        'data:final_data_contract:GroupedSplitInfeasible', ...
        ['The rounded complete-case test size cannot be achieved without ' ...
         'splitting a material group.']);
    selectedGroups=[requiredGroups;ordered(chosen)];
    selected=reshape(double(U.CaseID(complete&ismember(group,selectedGroups))),1,[]);
end

function selected=exact_group_subset(sizes,target)
    if target==0,selected=zeros(0,1);return,end
    reachable=false(target+1,1);reachable(1)=true;
    previousSum=nan(target+1,1);previousItem=nan(target+1,1);
    for item=1:numel(sizes)
        width=sizes(item);
        for old=target-width:-1:0
            if reachable(old+1)&&~reachable(old+width+1)
                reachable(old+width+1)=true;
                previousSum(old+width+1)=old;
                previousItem(old+width+1)=item;
            end
        end
    end
    if ~reachable(target+1),selected=zeros(0,1);return,end
    selected=zeros(numel(sizes),1);selectedCount=0;cursor=target;
    while cursor>0
        item=previousItem(cursor+1);selectedCount=selectedCount+1;
        selected(selectedCount)=item;
        cursor=previousSum(cursor+1);
    end
    selected=flipud(selected(1:selectedCount));
end

function values=normalize_split_groups(raw)
    values=string(raw(:));
    assert(~any(ismissing(values)|strlength(values)==0), ...
        'data:final_data_contract:SplitGroupValues', ...
        'Every case needs a split group; %d of %d have none.', ...
        nnz(ismissing(values)|strlength(values)==0),numel(values));
end

function tf=cell_text(value)
    tf=iscell(value)||isstring(value);
end
function tf=text_scalar(value)
    tf=ischar(value)||(isstring(value)&&isscalar(value));
end
function tf=positive_integer(value)
    tf=isnumeric(value)&&isscalar(value)&&isfinite(value)&&value==fix(value)&&value>0;
end
function tf=fraction(value)
    tf=isnumeric(value)&&isscalar(value)&&isfinite(value)&&value>0&&value<1;
end
function tf=case_vector(value)
    tf=isnumeric(value)&&(isempty(value)||isvector(value))&& ...
        all(isfinite(value))&&all(value==fix(value));
end
function tf=split_group_vector(value)
    tf=isempty(value)||isnumeric(value)||isstring(value)||iscellstr(value);
end
