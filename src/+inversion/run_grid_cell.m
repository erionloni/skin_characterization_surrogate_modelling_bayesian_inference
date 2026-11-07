function result = run_grid_cell(cfg,cellIndex,varargin)
%RUN_GRID_CELL The AIES inversion of one cell of the prepared canonical campaign.
%   RESULT = inversion.run_grid_cell(CFG,CELLINDEX) runs cell CELLINDEX (a row
%   of <campaign>/cell_task_table.csv) of the campaign prepared by
%   inversion.prepare_grid_campaign; 'Preparation',PREPARATION passes the
%   prepared campaign instead of reading it. The reliability controller
%   (inversion.run_reliability_cell) runs two independent AIES ensembles of 40
%   walkers per level, checks the health of each and the agreement of the
%   pair, and escalates from 2000 to 5000 steps. A certified cell saves its
%   certified posterior (inversion.save_certified_posterior), an uncertified
%   one its terminal decision; the cell's outcome record (cell_outcome.json
%   in the cell folder) is written last and marks the cell as run.
%   A cell with an outcome record is not run again. A cell that stopped
%   earlier reuses its finished requests (and a saved terminal decision).
%   Cells are independent: separate MATLAB processes, on one computer or on
%   a cluster, can each run their own cells.
%   RESULT: cellIndex, cellID, state ('certified' or 'unresolved'),
%   certified and samplerCallsPerformed (requests sampled by this call).
%   Computation: two ensembles per level; about 50 minutes per 2000-step
%   ensemble on a workstation.
%   Side effects: writes below the cell's folder of the campaign.

    parser=inputParser;
    parser.FunctionName='inversion.run_grid_cell';
    addParameter(parser,'Preparation',struct([]), ...
        @(x)isempty(x)||(isstruct(x)&&isscalar(x)));
    parse(parser,varargin{:});
    preparation=parser.Results.Preparation;
    if isempty(preparation)
        preparation=inversion.grid_campaign_support('load_preparation',cfg);
    end
    count=preparation.grid.cellCount;
    assert(isnumeric(cellIndex)&&isscalar(cellIndex)&& ...
        cellIndex==fix(cellIndex)&&cellIndex>=1&&cellIndex<=count, ...
        'inversion:run_grid_cell:CellIndex', ...
        'Inversion cells are grid indices 1 to %d of %s.',count, ...
        preparation.paths.taskTableCSV);
    cellRecord=preparation.cellRecords(cellIndex);
    outcomePath=inversion.grid_campaign_support('cell_outcome_path',cfg,cellRecord);
    if isfile(outcomePath)
        result=cell_result(cellRecord,jsondecode(fileread(outcomePath)),0);
        return
    end
    entry=inversion.grid_campaign_support('cell_entry',cfg,cellRecord);
    if ~isempty(entry)
        % An earlier call saved the terminal decision and stopped before
        % the outcome record.
        inversion.grid_campaign_support('write_cell_outcome',cfg,cellRecord,entry);
        result=cell_result(cellRecord,jsondecode(fileread(outcomePath)),0);
        return
    end

    P=parameters.parameter_space(cfg);
    saved=load(cfg.files.gp,'gp');
    assert(isfield(saved,'gp'), ...
        'inversion:run_grid_cell:GPArtifact', ...
        'The GP file %s does not contain the variable gp.',cfg.files.gp);
    seedMap=inversion.grid_campaign_support('seed_map',preparation);
    [decision,executions]=inversion.run_reliability_cell( ...
        cfg,cellRecord,saved.gp,P,seedMap);
    if decision.certified
        inversion.save_certified_posterior(cfg,cellRecord,decision);
    else
        inversion.grid_campaign_support('write_unresolved_decision', ...
            cfg,cellRecord,decision);
    end
    entry=inversion.grid_campaign_support('campaign_record', ...
        cellRecord,decision,executions, ...
        completion_state(executions),'');
    inversion.grid_campaign_support('write_cell_outcome',cfg,cellRecord,entry);
    result=cell_result(cellRecord,jsondecode(fileread(outcomePath)), ...
        nnz(~strcmp(string({executions.state}),"resumed_complete_request")));
end

function result=cell_result(cellRecord,outcome,samplerCalls)
    result=struct('cellIndex',double(cellRecord.cellIndex), ...
        'cellID',cellRecord.cellID, ...
        'state',char(string(outcome.terminalState)), ...
        'certified',logical(outcome.certified), ...
        'samplerCallsPerformed',samplerCalls);
end

function state=completion_state(executions)
    if isempty(executions)||all([executions.succeeded])
        state='complete';
    else
        state='complete_with_sampler_failures';
    end
end
