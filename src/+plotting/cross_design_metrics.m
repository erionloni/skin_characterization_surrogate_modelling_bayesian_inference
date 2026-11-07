function result = cross_design_metrics(cfg,cells)
%CROSS_DESIGN_METRICS The matched six-design comparisons behind the cross-design figures.
%   RESULT = plotting.cross_design_metrics(CFG, CELLS) derives, from the
%   saved posterior parameter table of the recovery (CELLS: the columns of
%   posterior_parameter_cells.csv), per scenario the cases available in
%   every design and the pairwise differences of each design from all_six.
%   It loads no surrogate, evaluates no likelihood and runs no inversion.
%   Side effects: none.

    designs=string(cfg.inversion.designNames(:));
    expectedDesigns=["all_six";"d2_only";"d6_only";"cycle_1_only"; ...
        "ratios_only";"physics_guided_full_rank_six"];
    assert(isequal(designs,expectedDesigns), ...
        'plotting:cross_design_metrics:DesignOrder', ...
        'Cross-design reporting requires the canonical ordered six designs.');
    parameters=string(cfg.paramNames(:));
    assert(numel(parameters)==4, ...
        'plotting:cross_design_metrics:ParameterCount', ...
        'The fixed-route comparison requires exactly four parameters.');
    required={'CaseID','Scenario','Design','Parameter','ArtifactLoaded', ...
        'NormalizedPosteriorSD','ContractionAmount'};
    assert(istable(cells)&&all(ismember(required, ...
        cells.Properties.VariableNames)), ...
        'plotting:cross_design_metrics:Schema', ...
        'The recovery table of posterior parameter cells has an unsupported schema.');

    cells.Scenario=string(cells.Scenario);
    cells.Design=string(cells.Design);
    cells.Parameter=string(cells.Parameter);
    loaded=as_logical(cells.ArtifactLoaded);
    normalizedSD=double(cells.NormalizedPosteriorSD);
    contraction=double(cells.ContractionAmount);
    validRow=loaded&isfinite(normalizedSD)&isfinite(contraction);
    caseIDs=reshape(double(cfg.inversion.caseIDs),[],1);
    scenarios=string(cfg.inversion.activeScenarioTags(:));
    template=empty_scenario();
    result=repmat(template,numel(scenarios),1);

    for s=1:numel(scenarios)
        scenario=scenarios(s);
        available=false(numel(caseIDs),numel(designs));
        for c=1:numel(caseIDs)
            for d=1:numel(designs)
                rows=cells.Scenario==scenario&cells.Design==designs(d)& ...
                    double(cells.CaseID)==caseIDs(c)& ...
                    ismember(cells.Parameter,parameters);
                available(c,d)=nnz(rows)==numel(parameters)&& ...
                    all(validRow(rows))&& ...
                    numel(unique(cells.Parameter(rows)))==numel(parameters);
            end
        end
        allMatched=all(available,2);
        matchedIDs=caseIDs(allMatched);
        result(s).scenario=char(scenario);
        result(s).availability=availability_table( ...
            scenario,caseIDs,designs,available);
        result(s).allDesignCohort=all_design_cohort( ...
            scenario,caseIDs,designs,available,allMatched);
        result(s).matchedCaseMetrics=matched_rows( ...
            cells,validRow,scenario,designs,parameters,matchedIDs);
        [result(s).medianNormalizedSD,result(s).medianMatrix]= ...
            median_matrix(result(s).matchedCaseMetrics,scenario, ...
            designs,parameters,matchedIDs);
        [result(s).pairwiseCohorts,result(s).differences]= ...
            pairwise_differences(cells,validRow,scenario,caseIDs, ...
            designs,parameters,available);
    end
end

function T=availability_table(scenario,caseIDs,designs,available)
    [caseGrid,designGrid]=ndgrid(caseIDs,1:numel(designs));
    T=table(repmat(scenario,numel(caseGrid),1),caseGrid(:), ...
        designs(designGrid(:)),available(:), ...
        'VariableNames',{'Scenario','CaseID','Design','ArtifactAvailable'});
end

function T=all_design_cohort(scenario,caseIDs,designs,available,included)
    matchedIDs=caseIDs(included);
    matchedText=id_text(matchedIDs);
    reasons=strings(numel(caseIDs),1);
    for c=1:numel(caseIDs)
        if included(c)
            reasons(c)="included_all_six_designs_certified";
        else
            reasons(c)="unavailable_designs:"+ ...
                strjoin(designs(~available(c,:)),"|");
        end
    end
    T=table(repmat(scenario,numel(caseIDs),1),caseIDs,included, ...
        repmat(nnz(included),numel(caseIDs),1), ...
        repmat(matchedText,numel(caseIDs),1),reasons, ...
        'VariableNames',{'Scenario','CaseID', ...
        'IncludedInAllDesignComparison','MatchedN','MatchedCaseIDs','Reason'});
end

function T=matched_rows(cells,validRow,scenario,designs,parameters,caseIDs)
    rows=validRow&cells.Scenario==scenario& ...
        ismember(cells.Design,designs)&ismember(cells.Parameter,parameters)& ...
        ismember(double(cells.CaseID),caseIDs);
    T=cells(rows,{'CaseID','Scenario','Design','Parameter', ...
        'NormalizedPosteriorSD','ContractionAmount'});
    if ~isempty(T)
        T.Design=categorical(string(T.Design),designs,'Ordinal',true);
        T.Parameter=categorical(string(T.Parameter),parameters,'Ordinal',true);
        T=sortrows(T,{'Design','Parameter','CaseID'});
        T.Design=string(T.Design);T.Parameter=string(T.Parameter);
    end
end

function [T,matrix]=median_matrix(cells,scenario,designs,parameters,caseIDs)
    matrix=nan(numel(designs),numel(parameters));
    for d=1:numel(designs)
        for p=1:numel(parameters)
            rows=string(cells.Design)==designs(d)& ...
                string(cells.Parameter)==parameters(p);
            values=double(cells.NormalizedPosteriorSD(rows));
            if ~isempty(values),matrix(d,p)=median(values);end
        end
    end
    T=table(designs,'VariableNames',{'Design'});
    numeric=array2table(matrix,'VariableNames',cellstr(parameters));
    T=[T numeric];
    T.Scenario=repmat(scenario,height(T),1);
    T.MatchedN=repmat(numel(caseIDs),height(T),1);
    T.MatchedCaseIDs=repmat(id_text(caseIDs),height(T),1);
    T=movevars(T,'Scenario','Before','Design');
end

function [cohorts,differences]=pairwise_differences( ...
        cells,validRow,scenario,caseIDs,designs,parameters,available)
    nComparison=numel(designs)-1;
    scenarioColumn=repmat(scenario,nComparison,1);
    referenceColumn=repmat(designs(1),nComparison,1);
    comparisonColumn=designs(2:end);
    roles=repmat("subset_or_transform_comparison",nComparison,1);
    roles(comparisonColumn=="physics_guided_full_rank_six")= ...
        "representation_parity";
    matchedN=zeros(nComparison,1);matchedCaseIDs=strings(nComparison,1);
    excludedCaseIDs=strings(nComparison,1);
    parts=cell(nComparison,1);
    for d=2:numel(designs)
        index=d-1;
        paired=available(:,1)&available(:,d);
        pairedIDs=caseIDs(paired);
        matchedN(index)=numel(pairedIDs);
        matchedCaseIDs(index)=id_text(pairedIDs);
        excludedCaseIDs(index)=id_text(caseIDs(~paired));
        parts{index}=difference_rows(cells,validRow,scenario, ...
            designs(d),parameters,pairedIDs,roles(index));
    end
    cohorts=table(scenarioColumn,referenceColumn,comparisonColumn,roles, ...
        matchedN,matchedCaseIDs,excludedCaseIDs, ...
        'VariableNames',{'Scenario','ReferenceDesign','ComparisonDesign', ...
        'ComparisonRole','MatchedN','MatchedCaseIDs','ExcludedCaseIDs'});
    differences=vertcat(parts{:});
end

function T=difference_rows( ...
        cells,validRow,scenario,design,parameters,caseIDs,role)
    if isempty(caseIDs),T=empty_differences();return;end
    n=numel(caseIDs)*numel(parameters);
    caseColumn=zeros(n,1);parameterColumn=strings(n,1);
    referenceSD=zeros(n,1);comparisonSD=zeros(n,1);
    referenceContraction=zeros(n,1);comparisonContraction=zeros(n,1);
    cursor=0;
    for c=1:numel(caseIDs)
        for p=1:numel(parameters)
            cursor=cursor+1;caseColumn(cursor)=caseIDs(c);
            parameterColumn(cursor)=parameters(p);
            reference=one_row(cells,validRow,scenario,"all_six", ...
                parameters(p),caseIDs(c));
            comparison=one_row(cells,validRow,scenario,design, ...
                parameters(p),caseIDs(c));
            referenceSD(cursor)=double(reference.NormalizedPosteriorSD);
            comparisonSD(cursor)=double(comparison.NormalizedPosteriorSD);
            referenceContraction(cursor)=double(reference.ContractionAmount);
            comparisonContraction(cursor)=double(comparison.ContractionAmount);
        end
    end
    T=table(repmat(scenario,n,1),caseColumn,parameterColumn, ...
        repmat("all_six",n,1),repmat(design,n,1),repmat(role,n,1), ...
        referenceSD,comparisonSD,comparisonSD-referenceSD, ...
        referenceContraction,comparisonContraction, ...
        comparisonContraction-referenceContraction, ...
        'VariableNames',{'Scenario','CaseID','Parameter','ReferenceDesign', ...
        'ComparisonDesign','ComparisonRole','ReferenceNormalizedPosteriorSD', ...
        'ComparisonNormalizedPosteriorSD','DeltaNormalizedPosteriorSD', ...
        'ReferenceContraction','ComparisonContraction','DeltaContraction'});
end

function row=one_row(cells,validRow,scenario,design,parameter,caseID)
    rows=validRow&cells.Scenario==scenario&cells.Design==design& ...
        cells.Parameter==parameter&double(cells.CaseID)==caseID;
    assert(nnz(rows)==1,'plotting:cross_design_metrics:DuplicateCell', ...
        'A matched case/design/parameter must resolve to exactly one row.');
    row=cells(rows,:);
end

function T=empty_differences()
    T=table('Size',[0 12],'VariableTypes', ...
        {'string','double','string','string','string','string', ...
        'double','double','double','double','double','double'}, ...
        'VariableNames',{'Scenario','CaseID','Parameter','ReferenceDesign', ...
        'ComparisonDesign','ComparisonRole','ReferenceNormalizedPosteriorSD', ...
        'ComparisonNormalizedPosteriorSD','DeltaNormalizedPosteriorSD', ...
        'ReferenceContraction','ComparisonContraction','DeltaContraction'});
end

function value=as_logical(input)
    if islogical(input),value=input;return;end
    if isnumeric(input),value=input~=0;return;end
    value=ismember(lower(string(input)),["true" "1"]);
end

function text=id_text(ids)
    ids=reshape(double(ids),1,[]);
    if isempty(ids),text="";else,text=strjoin(string(ids),"|");end
end

function value=empty_scenario()
    value=struct('scenario','','availability',table(), ...
        'allDesignCohort',table(),'matchedCaseMetrics',table(), ...
        'medianNormalizedSD',table(),'medianMatrix',nan(6,4), ...
        'pairwiseCohorts',table(),'differences',empty_differences());
end
