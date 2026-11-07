function manifest = saved_certification_summaries(cfg, ~)
%SAVED_CERTIFICATION_SUMMARIES The certification summary of single cells, one table per cell.
%   MANIFEST = plotting.saved_certification_summaries(CFG, OPTIONS) writes, in
%   reproduce mode, for every cell of the settings (A.10
%   'certificationSummaries') that has a posterior in the inversion's status
%   table (certified or a healthy fallback; an unavailable cell has none), the
%   per-case table <scenario>_<design>_certification
%   (cases/case_<CaseID>/inversion/tables/): the cell's row of the status
%   table (status, provider sampler, replicate and steps, whether it counts
%   in the certified-only values, the reason it is not certified) and, per
%   step level and parameter, its replicate agreement (normalized
%   Wasserstein distance and 2.5 % / 97.5 % quantile differences of the two
%   replicates, with the certification thresholds) and health diagnostics
%   (ensemble R-hat, tail and bulk ESS with their warning thresholds, which
%   do not affect certification) from diagnostics/pair_reliability_diagnostics.csv.
%   A cell without pair diagnostics (no second replicate) gets one row with
%   its status. Every value is copied as the saved tables hold it; nothing is
%   recomputed. MANIFEST is an empty figure manifest (tables only).
%   Outside reproduce mode it does nothing.
%   OPTIONS is unused.
%   Side effects: writes the tables and enters them in the index of the analysis.
%   Computation: seconds.

    manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
        'SourceArtifacts'});
    if ~study.is_publication(cfg), return; end
    statusPath = fullfile(study.source_folder(cfg, 'inversion'), 'cell_status.csv');
    if ~isfile(statusPath), return; end
    pairPath = fullfile(study.source_folder(cfg, 'inversion_diagnostics'), ...
        'pair_reliability_diagnostics.csv');
    statusColumns = {'CaseID', 'Scenario', 'Design', 'Status', 'ProviderSampler', ...
        'ProviderReplicate', 'ProviderSteps', 'InCertifiedOnlyValues', 'Reason'};
    pairColumns = {'StepCount', 'Campaign', 'PairStatus', 'PairCertified', 'PairReliable', ...
        'StructuralHealthPass', 'Parameter', 'NormalizedWasserstein', 'WassersteinThreshold', ...
        'NormalizedQ025Difference', 'NormalizedQ975Difference', 'QuantileThreshold', ...
        'EnsembleTimeRhat', 'RhatWarningThreshold', 'EnsembleTimeTailESS', ...
        'EnsembleTimeBulkESSRecordedV1', 'EnsembleTimeBulkESSCorrected', ...
        'BulkESSWarningThreshold', 'WarningDiagnosticsAffectCertification'};
    T = text_table(statusPath, statusColumns, 'inversion');
    sources = {statusPath};
    P = array2table(strings(0, numel(pairColumns) + 4), 'VariableNames', ...
        [{'CaseID', 'Scenario', 'Design', 'Condition'}, pairColumns]);
    if isfile(pairPath)
        P = text_table(pairPath, [{'CaseID', 'Scenario', 'Design', 'Condition'}, pairColumns], 'inversion');
        sources{end+1} = pairPath;
    end
    S = study.case_outputs(cfg, 'certificationSummaries');
    for k = 1:height(S)
        id = string(S.CaseID(k));
        mine = T.CaseID == id & T.Scenario == S.Scenario(k) & T.Design == S.Design(k) & ...
            ismember(T.Status, ["certified", "healthy fallback"]);
        if nnz(mine) ~= 1, continue; end
        pairs = P(P.CaseID == id & P.Scenario == S.Scenario(k) & P.Design == S.Design(k) & ...
            P.Condition == "", pairColumns);
        if isempty(pairs)
            pairs = array2table(strings(1, numel(pairColumns)), 'VariableNames', pairColumns);
        end
        summary = [repmat(T(mine, statusColumns), height(pairs), 1), pairs];
        scenario = char(S.Scenario(k));
        design = char(S.Design(k));
        study.export_table(cfg, 'case/inversion', sprintf('%s_%s_certification', scenario, design), ...
            summary, sources, sprintf(['Certification summary of case %d %s %s: status, provider, ' ...
            'replicate agreement and health diagnostics'], S.CaseID(k), strrep(scenario, '_', ' '), ...
            strrep(design, '_', ' ')), struct('CaseID', S.CaseID(k), 'Scenario', scenario, ...
            'Design', design));
    end
end

function T = text_table(pathValue, required, step)
%TEXT_TABLE A saved CSV table with every column as text, so that its values are copied unchanged.
    options = detectImportOptions(pathValue, 'Delimiter', ',');
    T = utils.read_csv_table(pathValue, options.VariableNames);
    assert(all(ismember(required, T.Properties.VariableNames)), ...
        'plotting:saved_certification_summaries:Schema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''%s''.', pathValue, ...
        strjoin(setdiff(required, T.Properties.VariableNames), ', '), step);
end
