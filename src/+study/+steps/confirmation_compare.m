function outcome = confirmation_compare(cfg, ~)
%CONFIRMATION_COMPARE Step 'compare': certification and paired comparisons of the confirmation.
%   OUTCOME = study.steps.confirmation_compare(CFG, STEPSINCALL) collects the
%   saved terminal decision of every cell of the campaign in
%   <run>/_run/confirmation (CFG.native.campaignRoot) with
%   confirmation.finalize_confirmation_campaign: the certification index
%   (certified or unresolved, with the provider), the posterior summaries
%   and the 60 paired comparisons of each selected protocol with the shared
%   default (weak-pair covariance, marginal variances, FIM proxy), over the
%   certified cells and the healthy fallbacks of the cells that were not
%   certified; then the status and the report. No sampler runs; the
%   summaries evaluate the frozen GP at saved posterior draws.
%   It then writes, below <run>/generalized/06_confirmation/data:
%     campaign/         the compact tier of the campaign (status,
%                       certification, summaries, cell grid and seed
%                       schedule, pairing, inputs, configuration records and
%                       reports; study.confirmation_compact_tier);
%     draws/            every retained draw of both replicates of the
%                       provider's level of every certified cell and every
%                       healthy fallback, one file per cell
%                       (<protocol>/<design>/case_<CaseID>.mat), with index.csv
%                       (study.write_confirmation_draws);
%     cell_status.csv   the campaign's status table, one row per material
%                       and protocol: certified, healthy fallback or
%                       unavailable (study.confirmation_status_table).
%   OUTCOME.details records the campaign status and cell counts.
%   Computation: minutes.
%   Side effects: writes the outputs above below the run folder.

    root = cfg.native.campaignRoot;
    preparation = confirmation.confirmation_campaign_support('load_preparation', root, cfg);
    status = confirmation.finalize_confirmation_campaign(preparation, study.screening_provider(cfg));
    data = fullfile(cfg.native.run, 'generalized', '06_confirmation', 'data');
    files = study.confirmation_compact_tier(root);
    for i = 1:numel(files)
        source = fullfile(root, strrep(files{i}, '/', filesep));
        destination = fullfile(data, 'campaign', strrep(files{i}, '/', filesep));
        if ~isfolder(fileparts(destination)), mkdir(fileparts(destination)); end
        copyfile(source, destination);
    end
    study.write_confirmation_draws(root, fullfile(data, 'draws'), ...
        run_relative(cfg.native.run, root));
    utils.atomic_write_table(fullfile(data, 'cell_status.csv'), ...
        study.confirmation_status_table(root));
    outcome = struct('published', true, 'details', struct('status', status.status, ...
        'planned_cells', status.planned_cell_count, ...
        'certified_cells', status.certified_cell_count));
end

function p = run_relative(run, pathValue)
%RUN_RELATIVE A folder inside the run folder, relative to it with '/'.
    run = utils.absolute_path(run);
    pathValue = utils.absolute_path(pathValue);
    assert(strncmpi(pathValue, [run filesep], numel(run) + 1), 'study:confirmation:OutsideRun', ...
        '%s is not inside the run folder %s.', pathValue, run);
    p = strrep(pathValue(numel(run) + 2:end), '\', '/');
end
