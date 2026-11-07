function T = confirmation_status_table(root)
%CONFIRMATION_STATUS_TABLE The status table of a compared confirmation campaign (one row per cell).
%   T = study.confirmation_status_table(ROOT) reads the cell status that the
%   step compare wrote for the campaign in ROOT
%   (summaries/confirmation_cell_status.csv, confirmation.summarize_confirmation;
%   the descriptive design of the complete pairs in
%   summaries/complete_pairs/) and returns the campaign's status table
%   (study.cell_status_columns 'confirmation'), one row per cell in the
%   campaign's order (the confirmation's design: one row per material and
%   protocol; then the cells of the complete pairs): its observation design
%   (cell_grid/confirmation_cell_grid.csv), Status certified, healthy
%   fallback (a healthy provider that was not certified) or unavailable (no
%   posterior), the provider, whether the cell counts in the certified-only
%   values (a certified cell) and why it is not certified, as recorded.
%   Side effects: none.

    grid = utils.read_csv_table(fullfile(root, 'cell_grid', 'confirmation_cell_grid.csv'), ...
        {'Protocol', 'ProtocolRole', 'InverseArtifactCellID', 'Scenario', 'Design', 'DesignRole'});
    files = {fullfile(root, 'summaries', 'confirmation_cell_status.csv'), ...
        fullfile(root, 'summaries', 'complete_pairs', 'confirmation_cell_status.csv')};
    assert(isfile(files{1}), 'study:confirmation_status_table:Missing', ...
        'The compared campaign lacks %s; run the step ''compare''.', files{1});
    parts = {};
    for k = 1:numel(files)
        if k > 1 && ~isfile(files{k}), continue; end
        parts{end+1} = one_design(files{k}, grid); %#ok<AGROW>
    end
    T = vertcat(parts{:});
end

function T = one_design(file, grid)
%ONE_DESIGN The status rows of the cells of one design's cell status.
    S = utils.read_csv_table(file, {'Protocol', 'ProtocolRole', 'ExecutionStatus', ...
        'FailureReason', 'ErrorIdentifier', 'CertifiedSampler', 'CertificationMechanism', ...
        'SelectedArtifactPath', 'SameLevelVerificationStatus', 'TerminationReason', 'ProviderKind'});
    kinds = ["certified", "healthy_completed_fallback", "unavailable"];
    names = ["certified", "healthy fallback", "unavailable"];
    [known, at] = ismember(S.ProviderKind, kinds);
    assert(all(known), 'study:confirmation_status_table:ProviderKind', ...
        'Unknown provider kinds in %s: %s.', file, strjoin(unique(S.ProviderKind(~known)), ', '));
    [inGrid, row] = ismember(double(S.ConfirmationCellIndex), double(grid.ConfirmationCellIndex));
    assert(all(inGrid), 'study:confirmation_status_table:Grid', ...
        'Cells of %s are not in the campaign''s cell grid.', file);
    status = reshape(names(at), [], 1);
    reason = strtrim(S.TerminationReason);
    reason(reason == "") = strtrim(S.FailureReason(reason == ""));
    reason(status == "certified") = "";
    sampler = S.CertifiedSampler;
    replicate = double(S.CertifiedReplicate);
    steps = double(S.CertifiedStepCount);
    sampler(status == "unavailable") = "";
    replicate(status == "unavailable") = NaN;
    steps(status == "unavailable") = NaN;
    T = table(double(S.MaterialCaseID), S.Protocol, S.ProtocolRole, grid.Design(row), status, ...
        sampler, replicate, steps, status == "certified", reason, 'VariableNames', ...
        study.cell_status_columns('confirmation'));
end
