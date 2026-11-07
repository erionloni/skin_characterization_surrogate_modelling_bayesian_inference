function grid=build_confirmation_grid(cfg,provider,design,observed,outputRoot)
%BUILD_CONFIRMATION_GRID The inverse cells and paired comparisons of the confirmation.
%   GRID = confirmation.build_confirmation_grid(CFG, PROVIDER, DESIGN, OBSERVED, OUTPUTROOT)
%   turns the design DESIGN (confirmation.confirmation_design) and its
%   accepted observations OBSERVED (confirmation.read_confirmation_observations,
%   design order) into:
%     - GRID.cells: the inverse cells. First one per design row, in design
%       order, with the confirmation's observation design (settings B.7
%       design, CFG.stage9bConfirmation.design: all_six or d2_only): the
%       material's truth (the four material parameters of PROVIDER, log10
%       k0), the observed pressures (NaN where none was accepted; a cell
%       reads the pressures of its design), the protocol (label, row, role
%       and its three GP inputs: log10 |rate|, hold, pause), scenario
%       measurement_plus_gp. A cell whose design row has no accepted
%       observation (OBSERVED.Accepted, the reviewer's exclusion) is
%       unavailable (available false, unavailableReason) and never runs.
%       Then, with a descriptive design of the complete pairs (B.7
%       completePairsDesign; '' for none), one cell of that design for the
%       selected row of every complete pair and one for the default row of
%       its material, in design order: a pair is complete when its default
%       and its selected row are both accepted and have every pressure of
%       that design. A cell is named by its material, scenario and design;
%       its posterior folder is <scenario>/<design>/case_<CaseID> below the
%       folder of its protocol (confirmation.confirmation_campaign_support,
%       'request_configurations'), its designRow is its row of the design
%       and its designRole 'primary' or 'complete_pairs'. The cell of the
%       reference protocol is shared by the comparisons of its material and
%       design;
%     - GRID.table: the cells as a table (with Design and DesignRole);
%     - GRID.comparisons: one row per design, selected protocol and material
%       (PairIndex: the primary design first, protocols in order, each with
%       every material in order; then the complete pairs in the same order)
%       with its reference and selected cell, Design and DesignRole;
%     - GRID.pairs: the comparisons with the material's truth, both
%       protocols and both observations, and whether each point is also a
%       training point of the generalized GP (within the coordinate
%       tolerance of the settings, per output where it was available): a
%       description of the cohort;
%     - GRID.protocols: the protocols of the design;
%     - GRID.designs: the observation designs of the cells (name, label,
%       role), the primary design first.
%   The four material parameters are unknown, the protocol is known.
%   Side effects: none.
%   Computation: seconds.

    rows=design.rows;P=design.protocols;n=height(rows);
    assert(height(observed)==n&&isequal(observed.DesignIndex,rows.DesignIndex), ...
        'confirmation:build_confirmation_grid:Observations', ...
        'The observations must hold one row per design row, in design order.');
    outputNames=cellstr(string(provider.outputNames));
    materialNames=cellstr(string(provider.materialParameterNames));
    primary=inversion.design_registry(cfg.stage9bConfirmation.design);
    designs=struct('name',primary.name,'label',primary.label,'role','primary');
    secondaryName='';
    if isfield(cfg.stage9bConfirmation,'completePairsDesign')
        secondaryName=char(string(cfg.stage9bConfirmation.completePairsDesign));
    end
    template=struct('cellIndex',NaN,'cellID','','caseID',NaN,'scenario','measurement_plus_gp', ...
        'scenarioLabel','Measurement + GP uncertainty','primaryScenario',true,'design','', ...
        'designLabel','','designRole','','designRow',NaN,'truth',zeros(1,4), ...
        'heldout_response',zeros(1,6),'protocol','','protocolIndex',NaN,'protocolRole','', ...
        'protocolVector',zeros(1,3),'MaterialCaseID',NaN,'available',true,'unavailableReason','');
    accepted=true(n,1);exclusion=strings(n,1);
    if ismember('Accepted',observed.Properties.VariableNames)
        accepted=logical(observed.Accepted);exclusion=string(observed.ExclusionReason);
    end
    cells=repmat(template,1,n);
    for i=1:n
        c=row_cell(template,i,i,primary,'primary',rows,observed,materialNames,outputNames);
        if ~accepted(i)
            % No accepted observation (the reviewer's exclusion): the cell is
            % unavailable and never runs; nothing is imputed.
            c.available=false;
            c.unavailableReason=char("no accepted COMSOL observation: "+exclusion(i));
        end
        cells(i)=c;
    end

    % The comparisons: every selected protocol against the reference
    % protocol (row 1) on the same material. The design lists the
    % protocols of each material together, so the row of material m and
    % protocol p is (m-1)*height(P)+p; a primary cell's index is its row.
    materials=design.materials.MaterialCaseID;
    selected=find(P.ProtocolRole=="selected");
    [m,s]=ndgrid(1:numel(materials),selected);m=m(:);s=s(:);
    defaultRow=(m-1)*height(P)+1;selectedRow=(m-1)*height(P)+s;
    comparisons=comparison_table(materials(m),P(s,:),defaultRow,selectedRow,primary.name,'primary');
    if ~isempty(secondaryName)
        % The complete pairs of the descriptive design: both rows accepted
        % and every pressure of that design observed.
        secondary=inversion.design_registry(secondaryName);
        designs(2)=struct('name',secondary.name,'label',secondary.label,'role','complete_pairs');
        values=observed{:,outputNames(secondary.sourceOutputIndices)};
        complete=accepted&all(isfinite(values),2);
        keep=complete(defaultRow)&complete(selectedRow);
        needed=unique([defaultRow(keep);selectedRow(keep)]);
        cellOf=zeros(n,1);
        for k=1:numel(needed)
            cellOf(needed(k))=n+k;
            cells(n+k)=row_cell(template,n+k,needed(k),secondary,'complete_pairs',rows, ...
                observed,materialNames,outputNames);
        end
        comparisons=[comparisons;comparison_table(materials(m(keep)),P(s(keep),:), ...
            cellOf(defaultRow(keep)),cellOf(selectedRow(keep)),secondary.name,'complete_pairs')];
    end
    comparisons.PairIndex=(1:height(comparisons)).';
    rowOf=[cells.designRow].';
    vector=reshape([cells.protocolVector],3,[]).';
    gridTable=table([cells.cellIndex].',[cells.MaterialCaseID].',string({cells.protocol}).', ...
        string({cells.protocolRole}).',string({cells.cellID}).',string({cells.scenario}).', ...
        string({cells.design}).',vector(:,1),vector(:,2),vector(:,3),[cells.available].', ...
        string({cells.designRole}).','VariableNames',{'ConfirmationCellIndex','MaterialCaseID', ...
        'Protocol','ProtocolRole','InverseArtifactCellID','Scenario','Design','Log10AbsRate', ...
        'Hold_s','Pause_s','Available','DesignRole'});
    grid=struct('cells',cells,'table',gridTable,'cellCount',numel(cells), ...
        'comparisons',comparisons,'pairs',paired_registry(cfg,comparisons,rows,observed, ...
            materialNames,outputNames,rowOf),'protocols',P,'designs',designs, ...
        'outputRoot',utils.absolute_path(outputRoot));
end

function c=row_cell(template,index,row,design,role,rows,observed,materialNames,outputNames)
%ROW_CELL The cell of one design row in one observation design.
    c=template;
    c.cellIndex=index;c.designRow=row;
    c.caseID=double(rows.MaterialCaseID(row));c.MaterialCaseID=c.caseID;
    c.design=design.name;c.designLabel=design.label;c.designRole=role;
    c.cellID=sprintf('case_%d|%s|%s',c.caseID,c.scenario,c.design);
    c.truth=rows{row,materialNames};
    c.heldout_response=observed{row,outputNames};
    c.protocol=char(rows.Protocol(row));c.protocolIndex=double(rows.ProtocolIndex(row));
    c.protocolRole=char(rows.ProtocolRole(row));
    c.protocolVector=[rows.Log10AbsRate(row) rows.Hold_s(row) rows.Pause_s(row)];
end

function T=comparison_table(materials,protocols,defaultCell,selectedCell,design,role)
%COMPARISON_TABLE The comparisons of one design: material, selected protocol and both cells.
    n=numel(materials);
    T=table(nan(n,1),materials(:),protocols.Protocol,protocols.ObjectiveID, ...
        protocols.ComparisonRole,double(defaultCell(:)),double(selectedCell(:)), ...
        repmat(string(design),n,1),repmat(string(role),n,1),'VariableNames',{'PairIndex', ...
        'MaterialCaseID','Protocol','ObjectiveID','ComparisonRole','DefaultCellIndex', ...
        'SelectedCellIndex','Design','DesignRole'});
end

function pairs=paired_registry(cfg,comparisons,rows,observed,materialNames,outputNames,rowOf)
%PAIRED_REGISTRY The comparisons with the truth, both protocols and observations, and the training overlap.
%   ROWOF maps a cell index to its design row.
    d=rowOf(comparisons.DefaultCellIndex);s=rowOf(comparisons.SelectedCellIndex);
    pairs=[comparisons(:,{'PairIndex','MaterialCaseID'}),rows(d,materialNames)];
    pairs.DefaultProtocol=rows.Protocol(d);
    pairs.SelectedProtocol=rows.Protocol(s);
    for name={'SignedRate_kPa_s','RateMagnitude_kPa_s','Log10AbsRate','Hold_s','Pause_s'}
        pairs.(['Default_' name{1}])=rows.(name{1})(d);
        pairs.(['Selected_' name{1}])=rows.(name{1})(s);
    end
    for j=1:numel(outputNames)
        pairs.(['Default_' outputNames{j}])=observed.(outputNames{j})(d);
        pairs.(['Selected_' outputNames{j}])=observed.(outputNames{j})(s);
    end
    % Whether the material and protocol also occur in the training data of
    % the generalized GP (per output where it was available): a
    % description of the cohort.
    dataset=utils.load_plain_mat(cfg.files.dataset,'X_train','X_development_all','developmentOutputAvailabilityMask');
    if isfield(dataset,'X_development_all')
        developmentX=double(dataset.X_development_all);
        availability=logical(dataset.developmentOutputAvailabilityMask);
    else
        developmentX=double(dataset.X_train);
        availability=true(size(developmentX,1),6);
    end
    tolerance=double(cfg.stage9bConfirmation.coordinateEqualityTolerance);
    n=height(pairs);
    anyDefault=false(n,1);anySelected=false(n,1);
    perDefault=false(n,numel(outputNames));perSelected=perDefault;
    for i=1:n
        theta=rows{d(i),materialNames};
        defaultMatch=near_rows(developmentX,[theta rows.Log10AbsRate(d(i)) rows.Hold_s(d(i)) ...
            rows.Pause_s(d(i))],tolerance);
        selectedMatch=near_rows(developmentX,[theta rows.Log10AbsRate(s(i)) rows.Hold_s(s(i)) ...
            rows.Pause_s(s(i))],tolerance);
        anyDefault(i)=any(defaultMatch);anySelected(i)=any(selectedMatch);
        perDefault(i,:)=any(defaultMatch&availability,1);
        perSelected(i,:)=any(selectedMatch&availability,1);
    end
    pairs.ExactGeneralizedTrainingOverlapDefault=anyDefault;
    pairs.ExactGeneralizedTrainingOverlapSelected=anySelected;
    for j=1:numel(outputNames)
        suffix=matlab.lang.makeValidName(outputNames{j});
        pairs.(['ExactGeneralizedTrainingOverlapDefault_' suffix])=perDefault(:,j);
        pairs.(['ExactGeneralizedTrainingOverlapSelected_' suffix])=perSelected(:,j);
    end
    pairs.ObjectiveID=comparisons.ObjectiveID;
    pairs.ComparisonRole=comparisons.ComparisonRole;
    pairs.Design=comparisons.Design;
    pairs.DesignRole=comparisons.DesignRole;
end

function tf=near_rows(matrix,row,tolerance)
    scale=max(1,max(abs(matrix),abs(row)));
    tf=all(abs(matrix-row)<=tolerance.*scale,2);
end
