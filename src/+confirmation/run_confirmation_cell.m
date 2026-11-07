function result = run_confirmation_cell(preparation,taskIndex,provider)
%RUN_CONFIRMATION_CELL The AIES inversion of one prepared confirmation cell.
%   RESULT = confirmation.run_confirmation_cell(PREPARATION, TASKINDEX, PROVIDER)
%   runs cell TASKINDEX of the prepared campaign PREPARATION
%   (confirmation.confirmation_campaign_support('load_preparation', ROOT, CFG)) with the
%   model PROVIDER (screening.generalized_provider: the approved generalized
%   package of the configuration). The reliability
%   controller of the inversion (inversion.run_reliability_cell) runs two
%   independent AIES ensembles of 40 walkers per level, checks the health of
%   each and the agreement of the pair, and escalates from 2000 to 5000
%   steps; its requests evaluate the generalized GP at the cell's known
%   protocol (confirmation.run_confirmation_request). A certified cell saves its
%   certified posterior (inversion.save_certified_posterior), an uncertified
%   one its terminal decision; the cell's outcome record (cell_outcome.json)
%   is written last and marks the cell as run.
%   A cell with an outcome record is not run again. A cell that stopped
%   earlier reuses its finished requests (and a saved terminal decision).
%   A cell without an accepted observation (the reviewer's exclusion;
%   confirmation.build_confirmation_grid) is unavailable: nothing runs and
%   nothing is written (State 'unavailable').
%   RESULT: TaskIndex, CellID, Protocol, State ('certified' or 'unresolved'),
%   Certified and SamplerCalls (requests sampled by this call).
%   Computation: two ensembles per level; hours per cell on a workstation.
%   Side effects: writes below the cell's folder of the campaign.

    count=preparation.grid.cellCount;
    assert(isnumeric(taskIndex)&&isscalar(taskIndex)&&taskIndex==fix(taskIndex)&& ...
        taskIndex>=1&&taskIndex<=count, ...
        'confirmation:run_confirmation_cell:TaskIndex', ...
        'Confirmation cells are task indices 1 to %d of %s.',count, ...
        preparation.paths.taskTableCSV);
    task=table2struct(preparation.taskTable(taskIndex,:));
    cellRecord=preparation.grid.cells(taskIndex);
    if isfield(cellRecord,'available')&&~cellRecord.available
        % No accepted observation (the reviewer's exclusion): nothing runs.
        result=struct('TaskIndex',double(task.TaskIndex),'CellID',char(string(task.CellID)), ...
            'Protocol',char(string(task.Protocol)),'State','unavailable','Certified',false, ...
            'SamplerCalls',0);
        fprintf('[confirmation] cell %d (%s, %s) is unavailable: %s\n',taskIndex, ...
            cellRecord.cellID,cellRecord.protocol,cellRecord.unavailableReason);
        return
    end
    cellCfg=preparation.protocolConfigurations.(cellRecord.protocol);
    outcomePath=confirmation.confirmation_campaign_support('cell_outcome_path',cellCfg,cellRecord);
    if isfile(outcomePath)
        result=cell_result(task,jsondecode(fileread(outcomePath)),0);
        return
    end
    saved=confirmation.confirmation_campaign_support('cell_outcome',cellCfg,cellRecord);
    if ~saved.missing
        % An earlier call saved the terminal decision and stopped before
        % the outcome record.
        entry=confirmation.confirmation_campaign_support('campaign_record',cellRecord, ...
            saved.decision,saved.decision.executedEvidence);
        confirmation.confirmation_campaign_support('write_cell_outcome',cellCfg,cellRecord,task,entry);
        result=cell_result(task,jsondecode(fileread(outcomePath)),0);
        return
    end

    P=parameters.parameter_space(cellCfg);
    assert(P.M==4&&isequal(P.names,provider.materialParameterNames)&& ...
        isequal(P.bounds,provider.materialBounds), ...
        'confirmation:run_confirmation_cell:MaterialPrior', ...
        'The material prior of the configuration differs from the model provider''s parameters or bounds.');
    seedMap=confirmation.confirmation_campaign_support('seed_map',preparation);
    [decision,executions]=inversion.run_reliability_cell(cellCfg,cellRecord, ...
        provider.gp,P,seedMap,'RequestRunner',@confirmation.run_confirmation_request);
    if decision.certified
        inversion.save_certified_posterior(cellCfg,cellRecord,decision);
    else
        confirmation.confirmation_campaign_support('write_unresolved_decision', ...
            cellCfg,cellRecord,decision);
    end
    entry=confirmation.confirmation_campaign_support('campaign_record', ...
        cellRecord,decision,executions);
    confirmation.confirmation_campaign_support('write_cell_outcome',cellCfg,cellRecord,task,entry);
    result=cell_result(task,jsondecode(fileread(outcomePath)), ...
        count_sampler_calls(executions));
end

function result=cell_result(task,outcome,samplerCalls)
    result=struct('TaskIndex',double(task.TaskIndex),'CellID',char(string(task.CellID)), ...
        'Protocol',char(string(task.Protocol)),'State',char(string(outcome.terminalState)), ...
        'Certified',logical(outcome.certified),'SamplerCalls',samplerCalls);
end

function count=count_sampler_calls(executions)
    if isempty(executions),count=0;return;end
    if isfield(executions,'state')
        count=nnz(~strcmp(string({executions.state}), ...
            "resumed_complete_request"));
    else
        count=numel(executions);
    end
end
