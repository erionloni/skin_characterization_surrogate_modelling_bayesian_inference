function result = run_conditional_cell(cfg,taskIndex,varargin)
%RUN_CONDITIONAL_CELL The AIES inversion of one cell of the prepared conditional campaign.
%   RESULT = inversion.run_conditional_cell(CFG,TASKINDEX) runs task TASKINDEX
%   (a row of orchestration/conditional_tasks.csv) of the campaign prepared
%   by inversion.prepare_conditional_campaign; 'Preparation',PREPARATION passes
%   the prepared campaign instead of reading it. The conditional reliability
%   controller (inversion.run_conditional_reliability_cell) runs two
%   independent AIES ensembles per level in the space of the free
%   parameters, checks health and agreement, and escalates from 2000 to 5000
%   steps. A certified cell saves its certified posterior
%   (inversion.save_conditional_certified_posterior), an uncertified one its
%   terminal decision; the outcome record (cell_outcome.json in the cell
%   folder) is written last and marks the cell as run.
%   A cell with an outcome record is not run again; a cell that stopped
%   earlier reuses its finished requests.
%   RESULT: taskIndex, cellID, state, certified.
%   Side effects: writes below the cell's folder of the campaign.
%   Computation: two to five MCMC requests (minutes to hours).

    parser=inputParser;
    parser.FunctionName='inversion.run_conditional_cell';
    addParameter(parser,'Preparation',struct([]),@isstruct);
    parse(parser,varargin{:});
    prep=parser.Results.Preparation;
    if isempty(prep)
        prep=inversion.conditional_campaign_contract('load_preparation',cfg);
    end
    count=numel(prep.tasks);
    assert(isnumeric(taskIndex)&&isscalar(taskIndex)&& ...
        taskIndex==fix(taskIndex)&&taskIndex>=1&&taskIndex<=count, ...
        'inversion:run_conditional_cell:TaskIndex', ...
        'Conditional cells are task indices 1 to %d.',count);
    task=prep.tasks(taskIndex);
    cellRecord=task.cellRecord;
    outcomePath=inversion.conditional_campaign_contract('cell_outcome_path', ...
        cfg,cellRecord);
    if isfile(outcomePath)
        result=cell_result(task,jsondecode(fileread(outcomePath)));
        return
    end
    baseline=inversion.conditional_campaign_contract('baseline_for_task',prep,task);
    entry=inversion.conditional_campaign_contract('cell_entry',cfg,cellRecord,baseline);
    if isempty(entry)
        saved=load(cfg.files.gp,'gp');
        assert(isfield(saved,'gp'), ...
            'inversion:run_conditional_cell:GPArtifact', ...
            'The GP file %s does not contain the variable gp.',cfg.files.gp);
        seedMap=inversion.conditional_campaign_contract('seed_map',prep.seedSchedule);
        condition=inversion.conditional_inversion_conditions(cfg,task.conditionCode);
        decision=inversion.run_conditional_reliability_cell( ...
            cfg,cellRecord,saved.gp,condition,seedMap);
        if decision.certified
            inversion.save_conditional_certified_posterior( ...
                cfg,cellRecord,condition,decision);
        else
            paths=inversion.conditional_posterior_artifact_paths( ...
                cfg,cellRecord,'AIES',1,decision.stepCount);
            utils.atomic_write_json(paths.reliabilityPath,decision, ...
                'AllowReplace',true);
        end
        entry=inversion.conditional_campaign_contract('cell_entry', ...
            cfg,cellRecord,baseline);
    end
    inversion.conditional_campaign_contract('write_cell_outcome',cfg,cellRecord,entry);
    result=cell_result(task,jsondecode(fileread(outcomePath)));
end

function result=cell_result(task,outcome)
    result=struct('taskIndex',double(task.taskIndex),'cellID',task.cellID, ...
        'state',char(string(outcome.terminalState)), ...
        'certified',logical(outcome.certified));
end
