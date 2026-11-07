function outcome = fixed_conditional_inversion(cfg, ~)
%FIXED_CONDITIONAL_INVERSION Step 'conditional_inversion' of the fixed route (optional).
%   OUTCOME = study.steps.fixed_conditional_inversion(CFG, STEPSINCALL) runs
%   the conditional inversions of the settings (A.9): per conditional case,
%   AIES inversions of the all_six observations with the parameters of each
%   condition fixed at the case's truth, in the scenarios of the campaign
%   rows. The condition that fixes nothing is the canonical all_six cell
%   itself: from the finalized inversion campaign of this run, or, without
%   one, from the shipped canonical results. The campaign code:
%     inversion.prepare_conditional_campaign   grid, seeds, the action of
%         every cell (run, reuse a cell the shipped results hold, skip a cell
%         whose baseline status is not accepted) and the task table of the
%         cells to run (written once; a later call continues the campaign)
%     inversion.run_conditional_cell           one cell, as in the canonical
%         campaign (replicate pairs, health checks, certification,
%         escalation); a completed cell is not run again
%     inversion.finalize_conditional_campaign  campaign record and reports
%   CFG.native.conditionalCells selects the cells of this call: 'all' (every
%   cell to run that has not run), 'prepare' (none; writes the task table)
%   or task indices (<run>/_run/inversion/conditional_inversion/
%   orchestration/conditional_tasks.csv). Cells are independent: separate
%   MATLAB processes, on one computer or on a cluster, can each run their
%   own indices after one 'prepare' call; a last call with 'all' runs
%   whatever is left and finalizes. When every cell to run has run, the
%   campaign is finalized and its results are written in the layout of
%   thesis_results/ to <run>/fixed/07_conditional_inversion/data
%   (study.write_conditional_results). With CFG.native.partialCampaign
%   (the example) the cells run so far are published without finalizing;
%   the others are unavailable, not run in this campaign.
%   OUTCOME has the fields of study.steps.fixed_inversion; its details also
%   name the MATLAB and UQLab lines that the cells ran with (their outcome
%   records), so that cells run on another computer keep their provenance.
%   Computation: per cell to run like a canonical cell (two AIES ensembles
%   per level).
%   Side effects: writes <run>/_run/inversion/conditional_inversion and, once
%   finalized, the results folder.
    preparation = inversion.prepare_conditional_campaign(cfg);
    actions = string({preparation.actions.action});
    n = numel(preparation.tasks);
    fprintf(['[study] conditional inversion: %d cells, %d to run, %d reused from the shipped ' ...
        'results, %d skipped (baseline status); the canonical cells are %s.\n'], ...
        numel(actions), n, nnz(actions == "reuse"), nnz(actions == "skip"), ...
        baseline_text(preparation.canonicalBarrier.source));
    selection = cfg.native.conditionalCells;
    if ischar(selection) && strcmp(selection, 'prepare')
        cells = [];
    elseif ischar(selection)
        cells = find(~cells_done(cfg, preparation));
    else
        assert(all(selection <= n), 'study:conditional:CellIndex', ...
            ['Conditional cells must be task indices in 1:%d (<run>/_run/inversion/' ...
             'conditional_inversion/orchestration/conditional_tasks.csv).'], n);
        cells = selection;
    end
    for k = reshape(cells, 1, [])
        fprintf('[study] conditional inversion cell %d of %d: %s\n', k, n, ...
            preparation.tasks(k).cellRecord.cellID);
        inversion.run_conditional_cell(cfg, k, 'Preparation', preparation);
    end
    done = cells_done(cfg, preparation);
    outcome = struct('cellCount', n, 'cellsRun', numel(cells), 'cellsDone', nnz(done), ...
        'complete', all(done), 'published', false, 'details', details(cfg, preparation, nnz(done)));
    if all(done)
        inversion.finalize_conditional_campaign(cfg, 'Preparation', preparation);
        study.write_conditional_results(cfg, preparation);
        outcome.published = true;
        fprintf('[study] conditional inversion: %d of %d cells done; campaign finalized.\n', ...
            nnz(done), n);
    elseif logical(cfg.native.partialCampaign) && any(done)
        % The cells run so far, published without finalizing (an example):
        % the others are unavailable, "not run in this campaign".
        inversion.finalize_conditional_campaign(cfg, 'Preparation', preparation, 'Partial', true);
        study.write_conditional_results(cfg, preparation);
        outcome.published = true;
        fprintf('[study] conditional inversion: %d of %d cells done; partial campaign published.\n', ...
            nnz(done), n);
    else
        fprintf(['[study] conditional inversion: %d of %d cells done; run the remaining cells, ' ...
            'then call again with ''ConditionalCells'',''all'' to finalize.\n'], nnz(done), n);
    end
end

function done = cells_done(cfg, preparation)
%CELLS_DONE True for the cells to run that have run (their outcome record exists).
    done = false(1, numel(preparation.tasks));
    for k = 1:numel(done)
        done(k) = isfile(inversion.conditional_campaign_contract('cell_outcome_path', cfg, ...
            preparation.tasks(k).cellRecord));
    end
end

function value = details(cfg, preparation, cellsDone)
%DETAILS What the run record keeps about the campaign.
    steps = [];
    if isfield(cfg.mcmc, 'demonstrationSteps'), steps = cfg.mcmc.demonstrationSteps; end
    actions = string({preparation.actions.action});
    conditions = inversion.conditional_inversion_conditions(cfg);
    value = struct('campaign_cells', numel(actions), 'cells_to_run', numel(preparation.tasks), ...
        'cells_done', cellsDone, 'cells_reused', nnz(actions == "reuse"), ...
        'cells_skipped', nnz(actions == "skip"), ...
        'campaign_complete', cellsDone == numel(preparation.tasks), ...
        'canonical_cells', preparation.canonicalBarrier.source, ...
        'conditions', struct('label', {conditions.code}, 'fixed', {conditions.fixedParameterNames}, ...
        'mask', {conditions.mask}), 'demonstration_steps', steps, ...
        'cell_environments', {cell_environments(cfg, preparation)});
end

function lines = cell_environments(cfg, preparation)
%CELL_ENVIRONMENTS The MATLAB and UQLab lines of the cells that have run, once each (their outcome records).
%   A cell that ran in another process or on a computing cluster records
%   the software it ran with; the run record keeps these lines as the
%   provenance of the cells.
    lines = {};
    for k = 1:numel(preparation.tasks)
        file = inversion.conditional_campaign_contract('cell_outcome_path', cfg, ...
            preparation.tasks(k).cellRecord);
        if ~isfile(file), continue; end
        record = jsondecode(fileread(file));
        if isfield(record, 'environment'), lines{end+1} = char(record.environment); end %#ok<AGROW>
    end
    lines = unique(lines, 'stable');
end

function text = baseline_text(source)
    if strcmp(source, 'shipped')
        text = 'the shipped ones (this run has no finalized inversion campaign)';
    else
        text = 'those of the finalized inversion campaign of this run';
    end
end
