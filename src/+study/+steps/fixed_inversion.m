function outcome = fixed_inversion(cfg, ~)
%FIXED_INVERSION Step 'inversion' of the fixed route: the AIES inversion campaign.
%   OUTCOME = study.steps.fixed_inversion(CFG, STEPSINCALL) runs the
%   canonical inversion grid of CFG (the cases CFG.inversion.caseIDs x 3
%   scenarios x 6 designs) with the unchanged campaign code:
%     inversion.prepare_grid_campaign   grid, cell records, seed schedule and
%                                     cell task table (written once; a
%                                     later call continues that campaign)
%     inversion.run_grid_cell           one cell: two independent AIES
%                                     ensembles per level (40 walkers),
%                                     single-analysis health checks,
%                                     replicate-pair certification,
%                                     escalation from 2000 to 5000 steps
%     inversion.finalize_grid_campaign  campaign record, certification index
%   CFG.native.inversionCells selects the cells of this call: 'all' (every
%   cell that has not run), 'prepare' (none; writes the task table) or
%   grid indices (see <run>/_run/inversion/cell_task_table.csv). Cells are
%   independent: separate MATLAB processes, on one computer or on a
%   cluster, can each run their own indices after one 'prepare' call; a
%   last call with 'all' runs whatever is left and finalizes.
%   When every cell has run, the campaign is finalized and its results are
%   written in the layout of thesis_results/ to <run>/fixed/04_inversion/data
%   (study.write_inversion_results). With CFG.native.partialCampaign the
%   cells run so far are written without finalizing; the others are
%   reported as not run.
%   Every request has its recorded thesis seed, or for a new cell the seed
%   of the settings' rule (seeds.mcmc), so every cell is reproducible on its
%   own.
%   OUTCOME has fields cellCount, cellsRun (this call), cellsDone, complete,
%   published (true when the results were written) and details (the state
%   of the campaign, the demonstration chain lengths and the MATLAB and
%   UQLab lines that its cells ran with, for the run record: cells run on
%   another computer keep their provenance).
%   Computation: on a workstation about 50 minutes per 2000-step ensemble
%   (two per cell and level; the thesis campaign has 360 cells); a few
%   minutes per cell with the demonstration chains of
%   CFG.mcmc.demonstrationSteps.
%   Side effects: writes <run>/_run/inversion and, once published,
%   <run>/fixed/04_inversion/data.

    preparation = inversion.prepare_grid_campaign(cfg);
    n = preparation.grid.cellCount;
    selection = cfg.native.inversionCells;
    if ischar(selection) && strcmp(selection, 'prepare')
        cells = [];
    elseif ischar(selection)
        cells = find(~cells_done(cfg, preparation));
    else
        assert(all(selection <= n), 'study:inversion:CellIndex', ...
            'Inversion cells must be grid indices in 1:%d (<run>/_run/inversion/cell_task_table.csv).', n);
        cells = selection;
    end
    for k = reshape(cells, 1, [])
        fprintf('[study] inversion cell %d of %d: %s\n', k, n, preparation.cellRecords(k).cellID);
        inversion.run_grid_cell(cfg, k, 'Preparation', preparation);
    end
    [done, environments] = cells_done(cfg, preparation);
    outcome = struct('cellCount', n, 'cellsRun', numel(cells), 'cellsDone', nnz(done), ...
        'complete', all(done), 'published', false, ...
        'details', campaign_details(cfg, n, nnz(done), environments));
    if all(done)
        inversion.finalize_grid_campaign(cfg, 'Preparation', preparation);
    end
    if all(done) || (logical(cfg.native.partialCampaign) && any(done))
        study.write_inversion_results(cfg, preparation, done);
        outcome.published = true;
    end
    fprintf('[study] inversion: %d of %d cells done%s.\n', nnz(done), n, ...
        conditional_text(outcome));
end

function details = campaign_details(cfg, cellCount, cellsDone, environments)
%CAMPAIGN_DETAILS What the run record keeps about the campaign, with the software its cells ran with.
    steps = [];
    if isfield(cfg.mcmc, 'demonstrationSteps'), steps = cfg.mcmc.demonstrationSteps; end
    details = struct('campaign_cells', cellCount, 'cells_done', cellsDone, ...
        'campaign_complete', cellsDone == cellCount, 'demonstration_steps', steps, ...
        'cell_environments', {environments});
end

function [done, environments] = cells_done(cfg, preparation)
%CELLS_DONE True for the cells that have run (their outcome record exists); the MATLAB and UQLab lines they ran with, once each.
%   A cell that ran in another process or on a computing cluster records
%   the software it ran with; the run record keeps these lines as the
%   provenance of the cells.
    done = false(1, preparation.grid.cellCount);
    environments = {};
    for k = 1:numel(done)
        file = inversion.grid_campaign_support('cell_outcome_path', cfg, preparation.cellRecords(k));
        done(k) = isfile(file);
        if ~done(k), continue; end
        record = jsondecode(fileread(file));
        if isfield(record, 'environment'), environments{end+1} = char(record.environment); end %#ok<AGROW>
    end
    environments = unique(environments, 'stable');
end

function text = conditional_text(outcome)
    if outcome.complete
        text = '; campaign finalized';
    elseif outcome.published
        text = '; partial campaign published';
    else
        text = sprintf(['; run the remaining cells, then call again with ' ...
            '''InversionCells'',''all'' to finalize']);
    end
end
