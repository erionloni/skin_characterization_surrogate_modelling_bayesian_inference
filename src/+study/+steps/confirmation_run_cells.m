function outcome = confirmation_run_cells(cfg, ~)
%CONFIRMATION_RUN_CELLS Step 'run_cells': the AIES inversion of the prepared confirmation cells.
%   OUTCOME = study.steps.confirmation_run_cells(CFG, STEPSINCALL) runs cells
%   of the campaign that the step 'prepare' wrote below <run>/_run/confirmation
%   (CFG.native.campaignRoot), each with confirmation.run_confirmation_cell: the
%   reliability controller of the inversion (inversion.run_reliability_cell: two
%   independent AIES ensembles of 40 walkers per level, single-analysis
%   health checks, replicate-pair certification, escalation from 2000 to
%   5000 steps; the requests evaluate the generalized GP at the cell's known
%   protocol, confirmation.run_confirmation_request). Each finished cell has an
%   outcome record (cell_outcome.json, with the MATLAB and UQLab versions it
%   ran with).
%   CFG.native.confirmationCells selects the cells of this call: 'all' (every
%   cell not yet run) or indices of the task table
%   (<run>/_run/confirmation/cell_grid/confirmation_task_table.csv). Cells are
%   independent: separate MATLAB processes, on one computer or on a cluster,
%   can each run their own indices. A finished cell is never run again.
%   The step is complete, and enters the run record, once every cell has
%   run; then the step 'compare' can run.
%   The cells run with the chains of their prepared campaign (shortened in
%   a demonstration campaign, 'DemonstrationSteps' of the step 'prepare').
%   OUTCOME has fields published (true when every cell is done) and details
%   (the state of the campaign, its demonstration chain lengths, and the
%   MATLAB and UQLab lines that its cells ran with: cells run on another
%   computer keep their provenance).
%   Computation: two ensembles per cell and level; a computing cluster for
%   the 80 cells (the fixed campaign needed about 50 minutes per 2000-step
%   ensemble on a workstation).
%   Side effects: writes the cells' request trees and outcome records below
%   <run>/_run/confirmation.

    root = cfg.native.campaignRoot;
    % With this call's configuration: a campaign prepared on another computer
    % runs with this computer's folders.
    preparation = confirmation.confirmation_campaign_support('load_preparation', root, cfg);
    n = preparation.grid.cellCount;
    selection = cfg.native.confirmationCells;
    if ischar(selection)
        cells = find(~cells_done(preparation));
    else
        assert(all(selection <= n), 'study:confirmation:CellIndex', ...
            'Confirmation cells are task indices in 1:%d (%s).', n, ...
            fullfile(root, 'cell_grid', 'confirmation_task_table.csv'));
        cells = selection;
    end
    provider = study.screening_provider(cfg);
    for k = reshape(cells, 1, [])
        fprintf('[study] confirmation cell %d of %d: case %d, protocol %s\n', k, n, ...
            preparation.grid.cells(k).MaterialCaseID, preparation.grid.cells(k).protocol);
        confirmation.run_confirmation_cell(preparation, k, provider);
    end
    [done, environments, unavailable] = cells_done(preparation);
    steps = [];
    if isfield(preparation.aiesPolicy, 'demonstrationSteps')
        steps = preparation.aiesPolicy.demonstrationSteps;
    end
    completePairs = 0;
    if isfield(preparation.grid.cells, 'designRole')
        completePairs = nnz(strcmp({preparation.grid.cells.designRole}, 'complete_pairs'));
    end
    outcome = struct('published', all(done), 'details', struct('campaign', 'confirmation', ...
        'campaign_cells', n, 'cells_complete_pairs', completePairs, ...
        'cells_done', nnz(done & ~unavailable), ...
        'cells_unavailable', nnz(unavailable), 'campaign_complete', all(done), ...
        'demonstration_steps', steps, 'cell_environments', {environments}));
    fprintf('[study] confirmation: %d of %d cells done (%d without an accepted observation)%s.\n', ...
        nnz(done & ~unavailable), n - nnz(unavailable), nnz(unavailable), conditional_text(all(done)));
end

function [done, environments, unavailable] = cells_done(preparation)
%CELLS_DONE True for the cells that have their outcome record; the MATLAB and UQLab lines they ran with, once each.
%   A cell that ran in another process or on a computing cluster records
%   the software it ran with; the run record keeps these lines as the
%   provenance of the cells. A cell without an accepted observation never
%   runs (UNAVAILABLE) and counts as done.
    done = false(1, preparation.grid.cellCount);
    unavailable = false(1, preparation.grid.cellCount);
    environments = {};
    for k = 1:numel(done)
        cellRecord = preparation.grid.cells(k);
        if isfield(cellRecord, 'available') && ~cellRecord.available
            unavailable(k) = true; done(k) = true;
            continue;
        end
        file = confirmation.confirmation_campaign_support('cell_outcome_path', ...
            preparation.protocolConfigurations.(cellRecord.protocol), cellRecord);
        done(k) = isfile(file);
        if ~done(k), continue; end
        record = jsondecode(fileread(file));
        if isfield(record, 'environment'), environments{end+1} = char(record.environment); end %#ok<AGROW>
    end
    environments = unique(environments, 'stable');
end

function text = conditional_text(complete)
    text = '; run the step ''compare''';
    if ~complete
        text = '; run the remaining cells (''ConfirmationCells'',''all'')';
    end
end
