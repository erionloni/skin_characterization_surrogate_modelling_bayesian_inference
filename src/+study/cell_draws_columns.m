function names = cell_draws_columns()
%CELL_DRAWS_COLUMNS Columns of draws/index.csv (one row per cell, schema v2).
%   NAMES = study.cell_draws_columns() lists the columns of the index of the
%   full posterior draws (thesis_results/fixed/<04|07>/data/draws/index.csv,
%   generalized/06_confirmation/data/draws/index.csv and the same files of
%   a run; study.write_cell_draws). Provider* and Partner* describe the two
%   replicates of the provider's level; Source is where the draws came from
%   (relative to the run; for imported confirmation draws
%   'import:<campaign folder>/<path>').
%   Side effects: none.
    names = {'CellID', 'CaseID', 'Scenario', 'Design', 'ConditionCode', 'State', 'Certified', ...
        'StepCount', 'ProviderReplicateID', 'ReplicateIDs', 'Walkers', 'RetainedIterations', ...
        'DrawCountPerReplicate', 'File', 'Bytes', 'ProviderSource', 'PartnerSource', ...
        'MissingReplicateReason'};
end
