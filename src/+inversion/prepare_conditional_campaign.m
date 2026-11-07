function preparation = prepare_conditional_campaign(cfg)
%PREPARE_CONDITIONAL_CAMPAIGN Prepare the conditional inversion campaign (grid, seeds, tasks), once.
%   PREPARATION = inversion.prepare_conditional_campaign(CFG) prepares the
%   conditional inversions of the settings (A.9): per conditional case, the
%   all_six observations inverted with the parameters of each condition of
%   the campaign fixed at the case's truth, in the campaign's scenarios
%   (inversion.build_conditional_inversion_grid). The condition that fixes
%   nothing is the canonical all_six cell itself, the baseline of the case
%   and scenario: from the finalized canonical campaign of this run, or,
%   when this run has none (study.reads_shipped_draws), from the canonical
%   results shipped in thesis_results/ (their status table and draws). Every
%   cell of the grid gets one action:
%     run    a task: the cell is run (inversion.run_conditional_cell);
%     reuse  with the setting reuseShippedCells and the shipped baseline, a
%            cell that the shipped conditional results hold: its status,
%            provider, draws and comparison rows are taken from them;
%     skip   its baseline's status is not one of the setting
%            baselineStatuses (certified, healthy fallback): it is not run
%            and is unavailable.
%   The seeds of all conditional requests are derived and checked to differ
%   from each other and from every canonical seed
%   (inversion.conditional_seed_schedule).
%   Writes below CFG.paths.conditionalInversion the grid, the seed schedule,
%   the task table (orchestration/conditional_tasks.csv: the cells to run),
%   the action of every cell (orchestration/conditional_cells.csv), the
%   baselines (orchestration/canonical_baseline_barrier.csv), the
%   preparation MAT and its summary JSON, with the demonstration chain
%   lengths of a demonstration campaign (CFG.mcmc.demonstrationSteps), which
%   every later call keeps. A campaign is prepared once: an existing
%   preparation is returned unchanged.
%   This function loads no GP and runs no sampler.
%   Side effects: writes the prepared campaign below its folder.
%   Computation: seconds.

    assert(strcmp(cfg.dataMode,'real')&& ...
        logical(cfg.conditionalInversion.enabled), ...
        'inversion:prepare_conditional_campaign:Disabled', ...
        'The conditional inversion is defined for the fixed route only.');
    if isfield(cfg,'parallelWorkers')&&double(cfg.parallelWorkers)>0
        error('inversion:prepare_conditional_campaign:ParallelNotEnabled', ...
            'Run the conditional inversion with ''ParallelWorkers'' 0.');
    end
    assert(isfile(cfg.files.dataset)&&isfile(cfg.files.gp), ...
        'inversion:prepare_conditional_campaign:Inputs', ...
        'The conditional inversion needs the dataset (%s) and the GP (%s).', ...
        cfg.files.dataset,cfg.files.gp);
    files=inversion.conditional_campaign_contract('paths',cfg);
    if isfile(files.preparation)
        preparation=inversion.conditional_campaign_contract('load_preparation',cfg);
        return
    end

    P=parameters.parameter_space(cfg);
    inversionCases=data.inversion_cases(cfg,P);
    cases=conditional_cases(cfg,inversionCases);
    grid=inversion.build_conditional_inversion_grid(cfg,cases);
    seedSchedule=inversion.conditional_seed_schedule(cfg,grid,inversionCases);
    barrier=canonical_barrier(cfg,cases);
    [tasks,actions]=build_tasks(cfg,cases,grid,barrier);
    preparation=struct( ...
        'schemaVersion','conditional_campaign_preparation_v3', ...
        'grid',grid,'seedSchedule',seedSchedule,'cases',cases, ...
        'canonicalBarrier',barrier,'tasks',tasks,'actions',actions, ...
        'parameterNames',{cellstr(string(cfg.paramNames(:))).'}, ...
        'parameterBounds',double(cfg.paramBounds), ...
        'demonstrationSteps',demonstration_steps(cfg));
    publish_preparation(preparation,files);
end

function steps=demonstration_steps(cfg)
%DEMONSTRATION_STEPS The shortened chain lengths of a demonstration campaign, [] for full chains.
%   Recorded with the preparation: every later call of the campaign runs
%   its cells with the same chains (study.run refuses other lengths).
    steps=[];
    if isfield(cfg.mcmc,'demonstrationSteps')
        steps=reshape(double(cfg.mcmc.demonstrationSteps),1,[]);
    end
end

function cases=conditional_cases(cfg,inversionCases)
%CONDITIONAL_CASES The case records of the conditional cases, in their order.
    ids=reshape(double([inversionCases.case_id]),1,[]);
    selected=reshape(double(cfg.conditionalInversion.caseIDs),1,[]);
    [present,where]=ismember(selected,ids);
    assert(all(present)&&~isempty(selected), ...
        'inversion:prepare_conditional_campaign:Cases', ...
        'The conditional cases %s must be cases of the inversion (%s).', ...
        mat2str(selected),mat2str(ids));
    cases=inversionCases(where);
end

function barrier=canonical_barrier(cfg,cases)
%CANONICAL_BARRIER The canonical all_six baseline of every case and scenario of the campaign, with its status.
%   From this run's finalized canonical campaign (a cell is certified or
%   unavailable: a run's own campaign selects certified providers only), or
%   from the shipped canonical results (certified, healthy fallback or
%   unavailable, and whether it counts in the certified-only values, as
%   their status table records).
    reference=inversion.conditional_inversion_conditions(cfg,cfg.conditionalInversion.referenceCode);
    scenarios=reference.scheduledScenarios;
    shipped=study.reads_shipped_draws(cfg);
    if shipped
        statusFile=fullfile(cfg.native.shippedDraws.results,'fixed','04_inversion','data', ...
            'cell_status.csv');
        assert(isfile(statusFile), ...
            'inversion:prepare_conditional_campaign:ShippedBaselines', ...
            ['The conditional inversion of a run without its own inversion takes the canonical ' ...
             'cells from the shipped results; their status table %s is missing.'],statusFile);
        status=utils.read_csv_table(statusFile,{'Scenario','Design','Status','Reason'});
        source='shipped';
    else
        campaignPath=fullfile(cfg.paths.stage04,'inversion_campaign.mat');
        assert(isfile(campaignPath), ...
            'inversion:prepare_conditional_campaign:CanonicalCampaignMissing', ...
            ['The conditional inversion starts from the finalized inversion campaign ' ...
             '(%s); run the step ''inversion'' until every cell has run.'],campaignPath);
        saved=load(campaignPath,'campaign');
        campaign=saved.campaign;
        source='campaign';
    end
    template=struct('cellID','','caseID',NaN,'scenario','','design','all_six', ...
        'status','','certified',false,'inCertifiedOnlyValues',false,'accepted',false, ...
        'source',source,'reason','');
    records=repmat(template,numel(cases)*numel(scenarios),1);cursor=0;
    for i=1:numel(cases)
        for s=1:numel(scenarios)
            cursor=cursor+1;
            record=canonical_record(cases(i),scenarios{s});
            if shipped
                hit=status.CaseID==record.caseID&status.Scenario==string(record.scenario)& ...
                    status.Design=="all_six";
                assert(nnz(hit)==1, ...
                    'inversion:prepare_conditional_campaign:CanonicalBaseline', ...
                    'The shipped status table %s does not list the canonical cell %s once.', ...
                    statusFile,record.cellID);
                state=char(status.Status(hit));reason=char(status.Reason(hit));
                counts=logical(status.InCertifiedOnlyValues(hit));
                if ~strcmp(state,'unavailable')
                    [~,loaded]=study.load_shipped_posterior(cfg,record);
                    assert(loaded.valid, ...
                        'inversion:prepare_conditional_campaign:CanonicalBaselineArtifact', ...
                        'The shipped baseline %s did not load: %s',record.cellID,loaded.reason);
                end
            else
                hit=strcmp({campaign.entries.cellID},record.cellID);
                assert(nnz(hit)==1, ...
                    'inversion:prepare_conditional_campaign:CanonicalBaseline', ...
                    'The inversion campaign of this run does not hold the canonical cell %s.', ...
                    record.cellID);
                state='unavailable';reason=char(string(campaign.entries(hit).reason));
                counts=false;
                if logical(campaign.entries(hit).certified)
                    [~,loaded]=inversion.load_certified_posterior(cfg,record);
                    assert(loaded.valid, ...
                        'inversion:prepare_conditional_campaign:CanonicalBaselineArtifact', ...
                        'The certified baseline %s did not load: %s',record.cellID,loaded.reason);
                    state='certified';reason='';counts=true;
                end
            end
            records(cursor)=struct('cellID',record.cellID,'caseID',record.caseID, ...
                'scenario',record.scenario,'design','all_six','status',state, ...
                'certified',strcmp(state,'certified'),'inCertifiedOnlyValues',counts, ...
                'accepted',ismember(state,cfg.conditionalInversion.baselineStatuses), ...
                'source',source,'reason',reason);
        end
    end
    barrier=struct('schemaVersion','conditional_canonical_barrier_v3', ...
        'source',source,'acceptedStatuses',{cfg.conditionalInversion.baselineStatuses}, ...
        'requiredBaselineCount',numel(records),'records',records);
end

function record=canonical_record(one,scenario)
    caseID=pick(one,{'case_id','caseID'});
    truth=reshape(double(one.truth),1,[]);
    observation=pick(one,{'heldout_response','heldoutResponse'});
    record=struct('cellID',sprintf('case_%d|%s|all_six',caseID,scenario), ...
        'caseID',double(caseID),'case_id',double(caseID), ...
        'truth',truth,'heldout_response',reshape(double(observation),1,[]), ...
        'scenario',scenario,'design','all_six');
end

function [tasks,actions]=build_tasks(cfg,cases,grid,barrier)
%BUILD_TASKS The tasks (cells to run) and the action of every cell of the grid.
    shippedCells=shipped_conditional_cells(cfg,barrier);
    actionTemplate=struct('cellIndex',0,'cellID','','caseID',NaN,'scenario','', ...
        'conditionCode','','conditionID','','action','','baselineCellID','', ...
        'baselineStatus','','status','','providerSampler','','providerReplicate',NaN, ...
        'providerSteps',NaN,'inCertifiedOnlyValues',false,'reason','');
    actions=repmat(actionTemplate,grid.cellCount,1);
    records={};descriptors={};
    for i=1:grid.cellCount
        record=inversion.conditional_campaign_contract( ...
            'attach_case',grid.cells(i),cases);
        baselineID=sprintf('case_%d|%s|all_six',record.caseID,record.scenario);
        b=barrier.records(strcmp({barrier.records.cellID},baselineID));
        assert(isscalar(b), ...
            'inversion:prepare_conditional_campaign:Baseline', ...
            'The conditional cell %s has no canonical baseline %s.', ...
            record.cellID,baselineID);
        action=actionTemplate;
        action.cellIndex=record.cellIndex;action.cellID=record.cellID;
        action.caseID=record.caseID;action.scenario=record.scenario;
        action.conditionCode=record.conditionCode;action.conditionID=record.conditionID;
        action.baselineCellID=baselineID;action.baselineStatus=b.status;
        shippedRow=[];
        if ~isempty(shippedCells)
            shippedRow=shippedCells(shippedCells.CaseID==record.caseID& ...
                shippedCells.Scenario==string(record.scenario)& ...
                shippedCells.Condition==string(record.conditionID),:);
        end
        if ~isempty(shippedRow)
            assert(height(shippedRow)==1, ...
                'inversion:prepare_conditional_campaign:ShippedCell', ...
                'The shipped status table lists the cell %s more than once.',record.cellID);
            action.action='reuse';action.status=char(shippedRow.Status);
            action.providerSampler=char(shippedRow.ProviderSampler);
            action.providerReplicate=double(shippedRow.ProviderReplicate);
            action.providerSteps=double(shippedRow.ProviderSteps);
            action.inCertifiedOnlyValues=logical(shippedRow.InCertifiedOnlyValues);
            action.reason=char(shippedRow.Reason);
        elseif ~b.accepted
            action.action='skip';action.status='unavailable';
            action.reason=sprintf('canonical baseline %s',b.status);
        else
            action.action='run';
            paths=inversion.conditional_posterior_artifact_paths( ...
                cfg,record,'AIES',1,cfg.mcmc.levels(1));
            descriptors{end+1}=struct('taskIndex',numel(descriptors)+1, ...
                'cellIndex',record.cellIndex,'cellID',record.cellID, ...
                'caseID',record.caseID,'scenario',record.scenario, ...
                'design',record.design,'conditionCode',record.conditionCode, ...
                'conditionID',record.conditionID, ...
                'canonicalBaselineCellID',baselineID, ...
                'cellFolder',inversion.conditional_campaign_contract('run_relative', ...
                paths.cellRoot,cfg.paths.runRoot)); %#ok<AGROW>
            records{end+1}=record; %#ok<AGROW>
        end
        actions(i)=action;
    end
    if isempty(descriptors)
        tasks=struct('taskIndex',{},'cellIndex',{},'cellID',{},'caseID',{}, ...
            'scenario',{},'design',{},'conditionCode',{},'conditionID',{}, ...
            'canonicalBaselineCellID',{},'cellFolder',{},'cellRecord',{});
        return
    end
    template=descriptors{1};template.cellRecord=records{1};
    tasks=repmat(template,numel(descriptors),1);
    for i=1:numel(descriptors)
        task=descriptors{i};task.cellRecord=records{i};tasks(i)=task;
    end
end

function shippedCells=shipped_conditional_cells(cfg,barrier)
%SHIPPED_CONDITIONAL_CELLS The conditional cells that the shipped results hold, when they are reused.
%   With reuseShippedCells and the shipped canonical baseline: the rows of
%   the shipped conditional status table without the canonical references;
%   otherwise empty.
    shippedCells=[];
    if ~(logical(cfg.conditionalInversion.reuseShippedCells)&&strcmp(barrier.source,'shipped'))
        return
    end
    statusFile=fullfile(cfg.native.shippedDraws.results,'fixed','07_conditional_inversion', ...
        'data','cell_status.csv');
    if ~isfile(statusFile),return;end
    reference=inversion.conditional_inversion_conditions(cfg,cfg.conditionalInversion.referenceCode);
    shippedCells=utils.read_csv_table(statusFile, ...
        {'Scenario','Design','Condition','Status','ProviderSampler','Reason'});
    shippedCells=shippedCells(shippedCells.Condition~=string(reference.id),:);
end

function publish_preparation(preparation,files)
    directories={files.root,files.orchestration, ...
        fullfile(files.root,'posteriors'),fullfile(files.root,'certification'), ...
        fullfile(files.root,'reports')};
    for i=1:numel(directories)
        if ~isfolder(directories{i}),mkdir(directories{i});end
    end
    utils.atomic_write_table(files.grid,inversion.conditional_campaign_contract( ...
        'grid_table',preparation.grid));
    utils.atomic_write_table(files.seedSchedule, ...
        inversion.conditional_campaign_contract('seed_table',preparation.seedSchedule));
    utils.atomic_write_table(files.taskTable, ...
        inversion.conditional_campaign_contract('task_table',preparation.tasks));
    utils.atomic_write_table(files.cellActions, ...
        inversion.conditional_campaign_contract('action_table',preparation.actions));
    utils.atomic_write_table(files.canonicalBarrier, ...
        inversion.conditional_campaign_contract('barrier_table', ...
        preparation.canonicalBarrier.records));
    utils.atomic_save_struct(files.preparation, ...
        struct('preparation',preparation),'-v7');
    actions=string({preparation.actions.action});
    summary=struct('schemaVersion','conditional_campaign_preparation_v3', ...
        'cellCount',preparation.grid.cellCount, ...
        'cellsToRun',nnz(actions=="run"),'cellsReused',nnz(actions=="reuse"), ...
        'cellsSkipped',nnz(actions=="skip"), ...
        'baselineSource',preparation.canonicalBarrier.source, ...
        'caseIDs',reshape(double([preparation.cases.case_id]),1,[]), ...
        'requiredBaselineCount',preparation.canonicalBarrier.requiredBaselineCount, ...
        'requestSeedCount',preparation.seedSchedule.requestCount, ...
        'demonstrationSteps',preparation.demonstrationSteps, ...
        'environment',utils.environment_line(), ...
        'preparedUTC',char(datetime('now','TimeZone','UTC', ...
            'Format','yyyy-MM-dd''T''HH:mm:ss''Z''')));
    utils.atomic_write_json(files.preparationJSON,summary,'AllowReplace',true);
end

function value=pick(source,names)
    for i=1:numel(names)
        if isfield(source,names{i})&&~isempty(source.(names{i}))
            value=source.(names{i});return
        end
    end
    error('inversion:prepare_conditional_campaign:Field', ...
        'Record lacks one of: %s.',strjoin(names,', '));
end
