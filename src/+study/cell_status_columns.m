function names = cell_status_columns(campaign)
%CELL_STATUS_COLUMNS Columns of an MCMC campaign's status table (data/cell_status.csv).
%   NAMES = study.cell_status_columns(CAMPAIGN) lists the columns of the
%   status table of the campaign CAMPAIGN, 'inversion' (the canonical
%   inversion, fixed/04_inversion/data/cell_status.csv), 'conditional'
%   (the conditional inversion, fixed/07_conditional_inversion/data/
%   cell_status.csv), 'gp_mean' (the GP-mean inversion,
%   fixed/09_gp_mean_inversion/data/cell_status.csv: the columns of
%   'inversion' and LevelsRun, the chain levels the cell ran, e.g.
%   "2000;5000", and Escalated, whether it ran beyond the first level) or
%   'confirmation' (generalized/06_confirmation/data/cell_status.csv), one
%   row per cell:
%     CaseID, Scenario, Design  the cell (the confirmation: MaterialCaseID,
%                               Protocol and ProtocolRole, default or
%                               selected, and Design, the cell's observation
%                               design: the confirmation's, or that of the
%                               complete pairs; scenario measurement_plus_gp
%                               for every cell)
%     Condition                 (conditional only) the condition, baseline
%                               for the canonical all-free reference
%     Status                    certified, healthy fallback (a selected
%                               provider that is not certified; the thesis
%                               results only), unavailable (no posterior) or
%                               not run (a partial campaign of a run)
%     ProviderSampler, ProviderReplicate, ProviderSteps
%                               the selected provider
%     InCertifiedOnlyValues     whether the cell counts in the certified-only
%                               values of the summaries (a certified cell)
%     Reason                    why the cell is not certified, as recorded
%                               (empty for a certified cell)
%     HealthNote                (inversion and gp_mean) the undefined or degenerate
%                               warning diagnostics of the cell's replicate
%                               pairs, per kind and step count
%                               (study.diagnostic_notes; "" when none)
%   The status table replaces the provider index, the provider status
%   records, the closures and the completion records of the thesis
%   campaigns. study.write_inversion_results,
%   study.write_conditional_results and the confirmation's step compare
%   (study.confirmation_status_table) write it; study.cell_status,
%   study.case_overview, study.load_shipped_posterior and the renderers read it.
%   Side effects: none.
    switch campaign
        case 'inversion'
            names = {'CaseID', 'Scenario', 'Design', 'Status', 'ProviderSampler', ...
                'ProviderReplicate', 'ProviderSteps', 'InCertifiedOnlyValues', 'Reason', 'HealthNote'};
        case 'conditional'
            names = {'CaseID', 'Scenario', 'Design', 'Condition', 'Status', 'ProviderSampler', ...
                'ProviderReplicate', 'ProviderSteps', 'InCertifiedOnlyValues', 'Reason'};
        case 'gp_mean'
            names = {'CaseID', 'Scenario', 'Design', 'Status', 'ProviderSampler', ...
                'ProviderReplicate', 'ProviderSteps', 'InCertifiedOnlyValues', 'Reason', 'HealthNote', ...
                'LevelsRun', 'Escalated'};
        case 'confirmation'
            names = {'MaterialCaseID', 'Protocol', 'ProtocolRole', 'Design', 'Status', ...
                'ProviderSampler', 'ProviderReplicate', 'ProviderSteps', 'InCertifiedOnlyValues', ...
                'Reason'};
        otherwise
            error('study:cell_status_columns:Campaign', ['No status table is defined for the ' ...
                'campaign "%s" (inversion, conditional, gp_mean or confirmation).'], campaign);
    end
end
