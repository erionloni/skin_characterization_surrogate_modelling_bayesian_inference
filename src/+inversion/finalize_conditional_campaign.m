function campaign = finalize_conditional_campaign(cfg,varargin)
%FINALIZE_CONDITIONAL_CAMPAIGN The records and reports of a complete conditional campaign.
%   CAMPAIGN = inversion.finalize_conditional_campaign(CFG) reads the terminal
%   decision of every cell that this campaign ran (certified provider or
%   unresolved decision) and writes, below CFG.paths.conditionalInversion:
%   the certification index of those cells, the comparison of the
%   conditions per case, scenario and parameter, the availability and
%   matched-cohort reports (recovery.summarize_conditional_inversion: every
%   cell of the campaign, the run, reused and skipped ones, and the canonical
%   reference of each case and scenario), the campaign MAT and its status
%   JSON. 'Preparation',PREPARATION passes the prepared campaign instead of
%   reading it. Every cell to run must have run (it refuses otherwise,
%   naming them); with 'Partial',true (a partial campaign published as an
%   example) the cells that have not run are unavailable, "not run in this
%   campaign", and the campaign record says that the campaign is partial.
%   It evaluates no GP and runs no sampler.
%   Side effects: writes the files above, replacing earlier versions.

    parser=inputParser;
    parser.FunctionName='inversion.finalize_conditional_campaign';
    addParameter(parser,'Preparation',struct([]),@isstruct);
    addParameter(parser,'Partial',false,@(x)islogical(x)&&isscalar(x));
    parse(parser,varargin{:});
    prep=parser.Results.Preparation;
    partial=parser.Results.Partial;
    if isempty(prep)
        prep=inversion.conditional_campaign_contract('load_preparation',cfg);
    end
    taskCount=numel(prep.tasks);
    records=cell(taskCount,1);
    for i=1:taskCount
        task=prep.tasks(i);
        baseline=inversion.conditional_campaign_contract('baseline_for_task',prep,task);
        records{i}=inversion.conditional_campaign_contract('cell_entry',cfg, ...
            task.cellRecord,baseline);
    end
    missing=find(cellfun(@isempty,records)).';
    assert(isempty(missing)||partial, ...
        'inversion:finalize_conditional_campaign:MissingTasks', ...
        ['The conditional campaign is complete when every cell to run has run; tasks %s ' ...
         'have not (orchestration/conditional_tasks.csv).'],mat2str(missing));
    entries=vertcat(records{:});
    notRun={};
    if ~isempty(missing),notRun={prep.tasks(missing).cellID};end

    files=inversion.conditional_campaign_contract('paths',cfg);
    summary=recovery.summarize_conditional_inversion(cfg,prep,notRun);
    campaign=inversion.conditional_campaign_contract( ...
        'build_campaign',cfg,prep,entries,summary);
    utils.atomic_write_table(files.certificationIndex, ...
        inversion.conditional_campaign_contract('entry_table',campaign.entries));
    utils.atomic_write_table(files.comparison,summary.comparison);
    utils.atomic_write_table(files.availability,summary.availability);
    utils.atomic_write_table(files.matchedCohorts,summary.matchedCohorts);
    utils.atomic_write_table(files.matchedSummary,summary.matchedSummary);
    utils.atomic_save_struct(files.campaign,struct('campaign',campaign),'-v7');
    utils.atomic_write_json(files.status, ...
        inversion.conditional_campaign_contract('status_payload',campaign,files), ...
        'AllowReplace',true);
end
