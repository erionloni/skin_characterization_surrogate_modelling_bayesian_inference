function outcome = fixed_gp_mean_inversion(cfg, ~)
%FIXED_GP_MEAN_INVERSION Step 'gp_mean_inversion' of the fixed route (optional).
%   OUTCOME = study.steps.fixed_gp_mean_inversion(CFG, STEPSINCALL) runs the
%   GP-mean inversion of the settings (A.13): per case, the AIES inversion
%   of its held-out COMSOL pressures (all_six) in the scenario gp_mean_det,
%   the GP mean as the forward model with the numerical floor only. The
%   cells are those of the canonical campaign code, in their own folder
%   (inversion.gp_mean_campaign_config): two independent ensembles per
%   level, health checks, certification and escalation as for a canonical
%   cell. The campaign code:
%     inversion.prepare_gp_mean_campaign   grid, seeds (checked against every
%         seed used before) and the task table (written once; a later call
%         continues the campaign)
%     inversion.run_grid_cell              one cell; a completed cell is not
%         run again
%     inversion.finalize_gp_mean_campaign  certification index and record
%   CFG.native.gpMeanCells selects the cells of this call: 'all' (every cell
%   that has not run), 'prepare' (none; writes the task table) or task
%   indices (<run>/_run/inversion/gp_mean_inversion/cell_task_table.csv).
%   Cells are independent: separate MATLAB processes, on one computer or on
%   a cluster, can each run their own indices after one 'prepare' call; a
%   last call with 'all' runs whatever is left and finalizes. When every
%   cell has run, the campaign is finalized and its results are written in
%   the layout of thesis_results/ to <run>/fixed/09_gp_mean_inversion/data
%   (study.write_gp_mean_results), with the best fit of every case
%   (data/best_fit, study.write_gp_mean_best_fit: the scenario's answer,
%   computed directly; no sampler). With CFG.native.partialCampaign (the
%   example) the cells run so far are published without finalizing; the
%   others are unavailable, not run in this campaign.
%   OUTCOME has the fields of study.steps.fixed_conditional_inversion; its
%   details name the MATLAB and UQLab lines that the cells ran with (their
%   outcome records).
%   Computation: per cell like a canonical cell (two AIES ensembles per
%   level); the best fit about 2-3 minutes per case.
%   Side effects: writes <run>/_run/inversion/gp_mean_inversion and, once
%   finalized, the results folder.
    preparation = inversion.prepare_gp_mean_campaign(cfg);
    campaignCfg = inversion.gp_mean_campaign_config(cfg);
    n = preparation.grid.cellCount;
    fprintf('[study] GP-mean inversion: %d cells (scenario gp_mean_det, all_six).\n', n);
    selection = cfg.native.gpMeanCells;
    if ischar(selection) && strcmp(selection, 'prepare')
        cells = [];
    elseif ischar(selection)
        cells = find(~cells_done(campaignCfg, preparation));
    else
        assert(all(selection <= n), 'study:gp_mean_inversion:CellIndex', ...
            ['GP-mean cells must be task indices in 1:%d (<run>/_run/inversion/' ...
             'gp_mean_inversion/cell_task_table.csv).'], n);
        cells = selection;
    end
    for k = reshape(cells, 1, [])
        fprintf('[study] GP-mean inversion cell %d of %d: %s\n', k, n, ...
            preparation.cellRecords(k).cellID);
        inversion.run_grid_cell(campaignCfg, k, 'Preparation', preparation);
    end
    done = cells_done(campaignCfg, preparation);
    outcome = struct('cellCount', n, 'cellsRun', numel(cells), 'cellsDone', nnz(done), ...
        'complete', all(done), 'published', false, ...
        'details', details(cfg, campaignCfg, preparation, nnz(done)));
    if all(done)
        inversion.finalize_gp_mean_campaign(cfg, 'Preparation', preparation);
        study.write_gp_mean_results(cfg, preparation, done);
        study.write_gp_mean_best_fit(cfg, preparation);
        outcome.published = true;
        fprintf('[study] GP-mean inversion: %d of %d cells done; campaign finalized.\n', nnz(done), n);
    elseif logical(cfg.native.partialCampaign) && any(done)
        % The cells run so far, published without finalizing (an example):
        % the others are unavailable, "not run in this campaign".
        study.write_gp_mean_results(cfg, preparation, done);
        study.write_gp_mean_best_fit(cfg, preparation);
        outcome.published = true;
        fprintf('[study] GP-mean inversion: %d of %d cells done; partial campaign published.\n', ...
            nnz(done), n);
    else
        fprintf(['[study] GP-mean inversion: %d of %d cells done; run the remaining cells, then ' ...
            'call again with ''GPMeanCells'',''all'' to finalize.\n'], nnz(done), n);
    end
end

function done = cells_done(campaignCfg, preparation)
%CELLS_DONE True for the cells that have run (their outcome record exists).
    done = false(1, preparation.grid.cellCount);
    for k = 1:numel(done)
        done(k) = isfile(inversion.grid_campaign_support('cell_outcome_path', campaignCfg, ...
            preparation.cellRecords(k)));
    end
end

function value = details(cfg, campaignCfg, preparation, cellsDone)
%DETAILS What the run record keeps about the campaign.
    steps = [];
    if isfield(cfg.mcmc, 'demonstrationSteps'), steps = cfg.mcmc.demonstrationSteps; end
    value = struct('campaign_cells', preparation.grid.cellCount, 'cells_done', cellsDone, ...
        'campaign_complete', cellsDone == preparation.grid.cellCount, ...
        'cases', reshape(double(preparation.inversionCaseIDs), 1, []), ...
        'scenario', 'gp_mean_det', 'design', char(cfg.gpMeanInversion.design), ...
        'demonstration_steps', steps, ...
        'cell_environments', {cell_environments(campaignCfg, preparation)});
end

function lines = cell_environments(campaignCfg, preparation)
%CELL_ENVIRONMENTS The MATLAB and UQLab lines of the cells that have run, once each (their outcome records).
    lines = {};
    for k = 1:preparation.grid.cellCount
        file = inversion.grid_campaign_support('cell_outcome_path', campaignCfg, ...
            preparation.cellRecords(k));
        if ~isfile(file), continue; end
        record = jsondecode(fileread(file));
        if isfield(record, 'environment'), lines{end+1} = char(record.environment); end %#ok<AGROW>
    end
    lines = unique(lines, 'stable');
end
