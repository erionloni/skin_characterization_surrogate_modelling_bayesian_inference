function summary = summarize_posterior_grid(cfg,grid)
%SUMMARIZE_POSTERIOR_GRID The posterior summaries of every cell of the inversion grid.
%   SUMMARY = recovery.summarize_posterior_grid(CFG, GRID) returns, per cell
%   and parameter of GRID, the posterior summaries of the selected provider,
%   certified or a healthy fallback (median, credible interval, width,
%   contraction, truth inclusion and recovery error), and the cell's status.
%   Missing or rejected cells stay explicit rows with NaN metrics. The
%   summaries by parameter, by scenario and by scenario and design aggregate
%   the cells with a provider, and carry next to each aggregate the same
%   aggregate over the certified cells alone (<column>_certified_only).
%   There is no design summary over the three scenarios:
%   their availability differs, and pooling it would mix the scenarios'
%   composition with the design effects. No sampler or UQLab analysis runs.
%   Columns ending in Physical (TruthPhysical, CI025Physical, ...) keep the
%   names of the shipped tables: their values are in the model coordinates
%   of the posterior, log10(k0) for the permeability (CLN-025).
%   Side effects: creates the UQLab input of the parameter space
%   (parameters.parameter_space).

    assert(isstruct(grid)&&isscalar(grid)&&isfield(grid,'cells')&& ...
        numel(grid.cells)==cfg.inversion.expectedCellCount, ...
        'recovery:summarize_posterior_grid:Grid', ...
        'The inversion grid must be one struct with %d cells.',cfg.inversion.expectedCellCount);
    P=parameters.parameter_space(cfg);
    nCells=numel(grid.cells);nParam=P.M;
    parameterParts=cell(nCells,1);statusParts=cell(nCells,1);
    correlationParts=cell(nCells,1);
    for i=1:nCells
        cellRecord=grid.cells(i);
        [artifact,status]=recovery.load_posterior_provider(cfg,cellRecord);
        statusParts{i}=status_row(cellRecord,status,artifact);
        if status.loaded
            parameterParts{i}=recovery.posterior_parameter_rows(cellRecord,artifact,P,status);
            correlationParts{i}=correlation_rows(cellRecord,artifact,P,status);
        else
            parameterParts{i}=recovery.posterior_parameter_rows(cellRecord,[],P,status);
            correlationParts{i}=missing_correlation_rows(cellRecord,P,status);
        end
    end
    parameterCells=vertcat(parameterParts{:});
    cellStatus=vertcat(statusParts{:});
    correlations=vertcat(correlationParts{:});
    assert(height(parameterCells)==nCells*nParam&&height(cellStatus)==nCells, ...
        'recovery:summarize_posterior_grid:RowCount', ...
        'Internal error: the posterior summary needs one row per cell and per cell and parameter.');

    % The same summaries over the certified cells alone:
    % the healthy fallbacks count as not loaded.
    certifiedCells=parameterCells;
    certifiedCells.ArtifactLoaded=certifiedCells.ArtifactLoaded& ...
        certifiedCells.CertificationMechanism=="CERTIFIED_AIES_REPLICATE_AGREEMENT";
    both=@(groups)certified_rows(utils.add_certified_only(aggregate(parameterCells,groups), ...
        aggregate(certifiedCells,groups),[groups,{'PlannedRows'}]));
    summary=struct( ...
        'schemaVersion', ...
            'posterior_grid_summary_v5_certified_and_fallback', ...
        'parameterCells',parameterCells, ...
        'cellStatus',cellStatus, ...
        'correlations',correlations, ...
        'byParameter',both({'Parameter'}), ...
        'byScenarioParameter',both({'Scenario','Parameter'}), ...
        'byScenarioDesignParameter',both( ...
            {'Scenario','Design','DesignRole','ComparisonClass','Parameter'}), ...
        'byScenario',both({'Scenario'}), ...
        'byScenarioDesign',both({'Scenario','Design','DesignRole','ComparisonClass'}));
    summary.complete=all(cellStatus.ArtifactLoaded);
    summary.plannedCellCount=nCells;
    summary.certifiedCellCount=sum(cellStatus.ArtifactLoaded& ...
        cellStatus.CertificationMechanism=="CERTIFIED_AIES_REPLICATE_AGREEMENT");
    summary.availableCellCount=sum(cellStatus.ArtifactLoaded);
    summary.unresolvedCellCount=nCells-summary.certifiedCellCount;
    summary.inversionRunCount=0;
end

function T=status_row(cellRecord,status,artifact)
    sampler="";replicate=NaN;steps=NaN;mechanism="";
    semantics=design_study.design_semantics(cellRecord.design);
    if status.loaded
        [sampler,replicate,steps]=provider_axes(artifact);
        mechanism=string(certification_mechanism(artifact));
    end
    T=table(double(cellRecord.cellIndex),double(cellRecord.caseID), ...
        string(cellRecord.scenario), ...
        string(cellRecord.design),string(semantics.role), ...
        string(semantics.comparison_class),string(cellRecord.cellID), ...
        logical(status.loaded),string(status.state),string(status.reason), ...
        string(status.errorIdentifier),string(sampler),double(replicate), ...
        double(steps),mechanism, ...
        'VariableNames',{'CellIndex','CaseID','Scenario', ...
        'Design','DesignRole','ComparisonClass','CellID','ArtifactLoaded', ...
        'ExecutionStatus','FailureReason', ...
        'ErrorIdentifier','CertifiedSampler','CertifiedReplicate', ...
        'CertifiedStepCount','CertificationMechanism'});
end

function T=correlation_rows(cellRecord,A,P,status)
    C=cov(double(A.drawsPhysical));R=corrcoef(double(A.drawsPhysical));
    pairs=nchoosek(1:P.M,2);n=size(pairs,1);
    covariance=zeros(n,1);correlation=zeros(n,1);
    for i=1:n
        covariance(i)=C(pairs(i,1),pairs(i,2));
        correlation(i)=R(pairs(i,1),pairs(i,2));
    end
    T=correlation_table(cellRecord,P,pairs,covariance,correlation, ...
        true(n,1),repmat(string(certification_mechanism(A)),n,1),status);
end

function T=missing_correlation_rows(cellRecord,P,status)
    pairs=nchoosek(1:P.M,2);n=size(pairs,1);
    T=correlation_table(cellRecord,P,pairs,nan(n,1),nan(n,1), ...
        false(n,1),repmat("",n,1),status);
end

function T=correlation_table( ...
        cellRecord,P,pairs,covariance,correlation,loaded,mechanism,status)
    n=size(pairs,1);
    semantics=design_study.design_semantics(cellRecord.design);
    T=table(repmat(double(cellRecord.caseID),n,1), ...
        repmat(string(cellRecord.scenario),n,1), ...
        repmat(string(cellRecord.design),n,1), ...
        repmat(string(semantics.role),n,1), ...
        repmat(string(semantics.comparison_class),n,1), ...
        repmat(string(cellRecord.cellID),n,1), ...
        reshape(string(P.names(pairs(:,1))),[],1), ...
        reshape(string(P.names(pairs(:,2))),[],1), ...
        covariance,correlation,loaded,mechanism, ...
        repmat(string(status.state),n,1), ...
        'VariableNames',{'CaseID','Scenario','Design','DesignRole', ...
        'ComparisonClass','CellID', ...
        'Parameter1','Parameter2','PosteriorCovariancePhysical', ...
        'PosteriorCorrelation','ArtifactLoaded','CertificationMechanism', ...
        'ExecutionStatus'});
end

function [sampler,replicate,steps]=provider_axes(A)
    provenance=recovery.posterior_provider_provenance(A);
    provider=provenance.provider;
    sampler=char(string(provider.sampler));
    replicate=double(provider.replicateID);steps=double(provider.stepCount);
end

function mechanism=certification_mechanism(A)
    provenance=recovery.posterior_provider_provenance(A);
    mechanism=char(string(provenance.certificationMechanism));
end

function T=aggregate(cells,groups)
    key=strings(height(cells),1);
    for i=1:numel(groups)
        key=key+"|"+string(cells.(groups{i}));
    end
    uniqueKeys=unique(key,'stable');parts=cell(numel(uniqueKeys),1);
    for i=1:numel(uniqueKeys)
        rows=key==uniqueKeys(i);first=find(rows,1);
        prefix=table();
        for g=1:numel(groups),prefix.(groups{g})=cells.(groups{g})(first);end
        loaded=cells.ArtifactLoaded(rows);valid=rows&cells.ArtifactLoaded;
        values={'NormalizedPosteriorSD','ContractionAmount', ...
            'TruthCovered50','TruthCovered95', ...
            'PosteriorMeanNormalizedRecoveryError', ...
            'PosteriorMedianNormalizedRecoveryError','CIWidth50Physical', ...
            'CIWidthPhysical'};
        row=prefix;
        row.PlannedRows=sum(rows);row.IncludedRows=sum(loaded);
        row.UnresolvedRows=row.PlannedRows-row.IncludedRows;
        for v=1:numel(values)
            x=double(cells.(values{v})(valid));x=x(isfinite(x));
            name=values{v};
            if isempty(x)
                row.(['Mean' name])=NaN;row.(['Median' name])=NaN;
                row.(['SD' name])=NaN;
            else
                row.(['Mean' name])=mean(x);row.(['Median' name])=median(x);
                row.(['SD' name])=std(x,0);
            end
        end
        row=add_loss_consistent_aggregates(row,cells,valid);
        parts{i}=row;
    end
    T=vertcat(parts{:});
end

function T=certified_rows(T)
%CERTIFIED_ROWS The certified-only count of the included rows is the number of certified rows.
%   IncludedRows: the case x parameter rows with a posterior (certified and
%   healthy fallback); CertifiedRows: those of certified cells, as the
%   status table records them.
    T=renamevars(T,'IncludedRows_certified_only','CertifiedRows');
end

function row=add_loss_consistent_aggregates(row,cells,valid)
    normAbs=finite_values( ...
        cells.NormalizedAbsoluteErrorFromPosteriorMedian(valid));
    normSquared=finite_values( ...
        cells.NormalizedSquaredErrorFromPosteriorMean(valid));
    absPhysical=finite_values( ...
        cells.AbsoluteErrorFromPosteriorMedianPhysical(valid));
    squaredPhysical=finite_values( ...
        cells.SquaredErrorFromPosteriorMeanPhysical(valid));
    signedMean=finite_values( ...
        cells.SignedErrorFromPosteriorMeanPhysical(valid));
    row.AcrossCaseMeanNormAbsErrorFromPosteriorMedian= ...
        mean_or_nan(normAbs);
    row.AcrossCaseMedianNormAbsErrorFromPosteriorMedian= ...
        median_or_nan(normAbs);
    row.AcrossCaseNormMSEFromPosteriorMean=mean_or_nan(normSquared);
    row.AcrossCaseNormRMSEFromPosteriorMean=sqrt( ...
        row.AcrossCaseNormMSEFromPosteriorMean);
    row.AcrossCaseMAEPhysicalFromPosteriorMedian=mean_or_nan(absPhysical);
    row.AcrossCaseMSEPhysicalFromPosteriorMean=mean_or_nan(squaredPhysical);
    row.AcrossCaseRMSEPhysicalFromPosteriorMean=sqrt( ...
        row.AcrossCaseMSEPhysicalFromPosteriorMean);
    row.AcrossCaseMeanSignedErrorPhysicalFromPosteriorMean= ...
        mean_or_nan(signedMean);
end

function value=finite_values(value)
    value=double(value);value=value(isfinite(value));
end

function value=mean_or_nan(input)
    if isempty(input),value=NaN;else,value=mean(input);end
end

function value=median_or_nan(input)
    if isempty(input),value=NaN;else,value=median(input);end
end
