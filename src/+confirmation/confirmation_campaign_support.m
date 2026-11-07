function varargout = confirmation_campaign_support(action,varargin)
%CONFIRMATION_CAMPAIGN_SUPPORT Shared parts of the confirmation campaign.
%   Used by confirmation.prepare_confirmation_campaign, run_confirmation_cell,
%   finalize_confirmation_campaign and load_available_posterior: the folder
%   layout of a campaign, the configurations of the protocols, the seed
%   schedule, the task table, the written preparation, the outcome of a
%   cell and the report. It contains no sampler, likelihood, GP, FIM or
%   posterior mathematics.
%
%   Actions (confirmation.confirmation_campaign_support(ACTION, ...)):
%     'paths'                   ROOT -> the campaign's folders and files
%     'portable_policy'         the confirmation policy without its folders
%     'request_configurations'  CFG, PROVIDER, ROOT, GRID -> one
%                               configuration per protocol
%     'seed_schedule'           CFG, GRID -> the request seeds of every cell
%     'seed_map'                PREPARATION -> seed -> request
%     'design_grid'             GRID, DESIGN -> the cells, comparisons and
%                               pairs of one observation design
%     'task_table'              GRID, CONFIGURATIONS, ROOT -> one task per cell
%     'publish_preparation'     PREPARATION -> writes it below its root
%     'load_preparation'        ROOT[, CFG] -> the prepared campaign, with
%                               field names that this MATLAB can address;
%                               with the calling configuration CFG its protocol
%                               configurations use this computer's folders
%                               (a campaign prepared on one computer runs
%                               on another)
%     'cell_outcome'            CFG, CELL -> its saved terminal decision
%     'cell_outcome_path'       CFG, CELL -> its outcome record
%     'write_cell_outcome'      writes a finished cell's outcome record
%     'write_unresolved_decision'  writes an uncertified terminal decision
%     'campaign_record'         CELL, DECISION, EVIDENCE -> the cell's row
%                               of the certification index
%     'certification_table'     ENTRIES -> the certification index
%     'confirmation_report'     the Markdown report of a compared campaign
%
%   Side effects: 'publish_preparation', 'write_cell_outcome' and
%   'write_unresolved_decision' write below the campaign folder; the other
%   actions only read.

    action=char(string(action));
    switch action
        case 'paths'
            varargout{1}=campaign_paths(varargin{1});
        case 'portable_policy'
            varargout{1}=portable_policy(varargin{1});
        case 'request_configurations'
            varargout{1}=request_configurations(varargin{:});
        case 'seed_schedule'
            [varargout{1:nargout}]=seed_schedule(varargin{:});
        case 'seed_map'
            varargout{1}=seed_map(varargin{1});
        case 'design_grid'
            varargout{1}=design_grid(varargin{:});
        case 'task_table'
            varargout{1}=task_table(varargin{:});
        case 'publish_preparation'
            publish_preparation(varargin{1});
        case 'load_preparation'
            varargout{1}=load_preparation(varargin{:});
        case 'cell_outcome'
            varargout{1}=cell_outcome(varargin{:});
        case 'cell_outcome_path'
            varargout{1}=cell_outcome_path(varargin{:});
        case 'write_cell_outcome'
            write_cell_outcome(varargin{:});
        case 'write_unresolved_decision'
            varargout{1}=write_unresolved_decision(varargin{:});
        case 'campaign_record'
            varargout{1}=campaign_record(varargin{:});
        case 'certification_table'
            varargout{1}=certification_table(varargin{1});
        case 'confirmation_report'
            varargout{1}=confirmation_report(varargin{:});
        otherwise
            error('confirmation:confirmation_campaign_support:Action', ...
                'Unsupported confirmation-campaign action "%s".',action);
    end
end

function paths=campaign_paths(root)
    root=utils.absolute_path(root);
    paths=struct('root',root, ...
        'configurationRoot',fullfile(root,'configuration'), ...
        'inputsRoot',fullfile(root,'inputs'), ...
        'pairingRoot',fullfile(root,'pairing'), ...
        'cellGridRoot',fullfile(root,'cell_grid'), ...
        'aiesRoot',fullfile(root,'aies'), ...
        'certificationRoot',fullfile(root,'certification'), ...
        'summariesRoot',fullfile(root,'summaries'), ...
        'figuresRoot',fullfile(root,'figures'), ...
        'reportsRoot',fullfile(root,'reports'), ...
        'statusRoot',fullfile(root,'status'));
    paths.configurationJSON=fullfile(paths.configurationRoot,'confirmation_configuration.json');
    paths.preparationMAT=fullfile(paths.configurationRoot,'confirmation_preparation.mat');
    paths.preparationJSON=fullfile(paths.configurationRoot,'confirmation_preparation.json');
    paths.protocolsCSV=fullfile(paths.inputsRoot,'protocols.csv');
    paths.observationsCSV=fullfile(paths.inputsRoot,'observations.csv');
    paths.pairedRegistryCSV=fullfile(paths.pairingRoot,'paired_material_registry.csv');
    paths.gridCSV=fullfile(paths.cellGridRoot,'confirmation_cell_grid.csv');
    paths.comparisonsCSV=fullfile(paths.cellGridRoot,'pairwise_comparisons.csv');
    paths.taskTableCSV=fullfile(paths.cellGridRoot,'confirmation_task_table.csv');
    paths.seedScheduleCSV=fullfile(paths.cellGridRoot,'confirmation_seed_schedule.csv');
    paths.certificationIndexCSV=fullfile(paths.certificationRoot,'aies_certification_index.csv');
    paths.reportMD=fullfile(paths.reportsRoot,'confirmation_report.md');
    paths.statusJSON=fullfile(paths.statusRoot,'confirmation_status.json');
end

function configurations=request_configurations(cfg,provider,root,grid)
%REQUEST_CONFIGURATIONS One configuration per protocol of the design.
%   Each writes its cells' requests below ROOT/aies/<protocol>, where a
%   cell's folder is named by its material's CaseID. The runtime field names
%   the protocol.
    configurations=struct();
    for k=1:height(grid.protocols)
        label=char(grid.protocols.Protocol(k));one=cfg;
        one.paramNames=provider.materialParameterNames;
        one.paramUnits=cfg.paramUnits(1:4);
        one.paramBounds=provider.materialBounds;
        one.paths.stage04=fullfile(root,'aies',label);
        one.inversion.expectedCellCount=nnz(strcmp({grid.cells.protocol},label));
        one.stage9bConfirmation.runtime=struct('protocol',label);
        configurations.(label)=one;
    end
end

function [records,value]=seed_schedule(cfg,grid)
%SEED_SCHEDULE The request seed of every cell, level and replicate (seeds.confirmation).
    levels=reshape(double(cfg.mcmc.levels),1,[]);
    replicates=reshape(double(cfg.mcmc.productionReplicateIDs),1,[]);
    assert(strcmp(char(string(cfg.mcmc.productionSampler)),'AIES')&& ...
        isequal(levels,[2000 5000])&&isequal(replicates,[1 2])&& ...
        ~logical(cfg.mcmc.enableAdaptiveMetropolisValidation), ...
        'confirmation:confirmation_campaign_support:SeedPolicy', ...
        'The confirmation requires two independent AIES replicates at 2000 and 5000 steps only.');
    template=struct('TaskIndex',NaN,'CellID','','MaterialCaseID',NaN,'Protocol','', ...
        'ProtocolIndex',NaN,'Design','','Sampler','','ReplicateID',NaN,'StepCount',NaN,'Seed',NaN, ...
        'Request','');
    records=repmat(template,1,grid.cellCount*numel(levels)*numel(replicates));
    cursor=0;
    for c=1:grid.cellCount
        cellRecord=grid.cells(c);
        for level=levels
            for replicate=replicates
                [seed,record]=seeds.confirmation(cfg,cellRecord.MaterialCaseID, ...
                    cellRecord.protocolIndex,'AIES',replicate,level,cellRecord.design);
                cursor=cursor+1;
                records(cursor)=struct('TaskIndex',double(c),'CellID',cellRecord.cellID, ...
                    'MaterialCaseID',double(cellRecord.MaterialCaseID), ...
                    'Protocol',cellRecord.protocol,'ProtocolIndex',double(cellRecord.protocolIndex), ...
                    'Design',cellRecord.design,'Sampler','AIES','ReplicateID',double(replicate), ...
                    'StepCount',double(level),'Seed',double(seed),'Request',record.request);
            end
        end
    end
    % Two requests with one seed would not be independent ensembles.
    assert(numel(unique([records.Seed]))==numel(records), ...
        'confirmation:confirmation_campaign_support:SeedCollision', ...
        'Two confirmation requests have the same seed.');
    value=struct2table(records);
end

function map=seed_map(preparation)
    map=containers.Map('KeyType','char','ValueType','char');
    for i=1:numel(preparation.seedRecords)
        one=preparation.seedRecords(i);
        map(sprintf('%d',one.Seed))=one.Request;
    end
end

function names=design_names(grid)
%DESIGN_NAMES The observation designs of the campaign's cells, the primary design first.
    names={grid.designs.name};
end

function sub=design_grid(grid,design)
%DESIGN_GRID The cells, comparisons and pairs of one observation design of GRID.
%   The cells keep their campaign index (the certification index and the
%   task table name them by it); the comparisons and pairs keep their
%   PairIndex. A grid prepared before the complete pairs (no designs) is
%   one design.
    design=char(string(design));
    if ~isfield(grid,'designs'),sub=grid;return;end
    keep=strcmp({grid.cells.design},design);
    assert(any(strcmp({grid.designs.name},design)), ...
        'confirmation:confirmation_campaign_support:Design', ...
        'The campaign has no cells of the observation design %s.',design);
    sub=grid;
    sub.cells=grid.cells(keep);
    sub.cellCount=nnz(keep);
    sub.table=grid.table(grid.table.Design==string(design),:);
    sub.comparisons=grid.comparisons(grid.comparisons.Design==string(design),:);
    sub.pairs=grid.pairs(grid.pairs.Design==string(design),:);
    sub.designs=grid.designs(strcmp({grid.designs.name},design));
end

function value=task_table(grid,configurations,root)
%TASK_TABLE One task per inverse cell: its material, truth, protocol and cell folder.
    template=struct('TaskIndex',NaN,'CellID','','MaterialCaseID',NaN,'Protocol','', ...
        'ProtocolRole','','m3_f_RD',NaN,'m3_e_RD',NaN,'log10_k0_RD',NaN,'Thickness_RD',NaN, ...
        'SignedRate_kPa_s',NaN,'RateMagnitude_kPa_s',NaN,'Log10AbsRate',NaN,'Hold_s',NaN, ...
        'Pause_s',NaN,'Scenario','','Design','','CellFolder','');
    records=repmat(template,1,grid.cellCount);
    P=grid.protocols;
    for i=1:grid.cellCount
        cellRecord=grid.cells(i);p=P(cellRecord.protocolIndex,:);
        one=configurations.(cellRecord.protocol);
        artifact=inversion.posterior_artifact_paths(one,cellRecord,'AIES',1,one.mcmc.levels(1));
        records(i)=struct('TaskIndex',double(i),'CellID',cellRecord.cellID, ...
            'MaterialCaseID',double(cellRecord.MaterialCaseID),'Protocol',cellRecord.protocol, ...
            'ProtocolRole',cellRecord.protocolRole, ...
            'm3_f_RD',double(cellRecord.truth(1)),'m3_e_RD',double(cellRecord.truth(2)), ...
            'log10_k0_RD',double(cellRecord.truth(3)),'Thickness_RD',double(cellRecord.truth(4)), ...
            'SignedRate_kPa_s',double(p.SignedRate_kPa_s), ...
            'RateMagnitude_kPa_s',double(p.RateMagnitude_kPa_s), ...
            'Log10AbsRate',double(p.Log10AbsRate),'Hold_s',double(p.Hold_s), ...
            'Pause_s',double(p.Pause_s),'Scenario',cellRecord.scenario, ...
            'Design',cellRecord.design,'CellFolder',relative_inside(artifact.cellRoot,root));
    end
    value=struct2table(records);
end

function publish_preparation(preparation)
%PUBLISH_PREPARATION Write the prepared campaign below its root, once.
    paths=preparation.paths;
    assert(~isfile(paths.preparationMAT), ...
        'confirmation:confirmation_campaign_support:AlreadyPrepared', ...
        ['A confirmation campaign is already prepared in %s. Its cells, seeds and ' ...
         'tasks stay as prepared; prepare a new campaign in a new run (''RunName'').'], ...
        paths.root);
    names={'configurationRoot','inputsRoot','pairingRoot','cellGridRoot', ...
        'aiesRoot','certificationRoot','summariesRoot','figuresRoot', ...
        'reportsRoot','statusRoot'};
    for i=1:numel(names)
        if ~isfolder(paths.(names{i})),mkdir(paths.(names{i}));end
    end
    grid=preparation.grid;
    utils.atomic_write_json(paths.configurationJSON,preparation.configuration);
    utils.atomic_write_exact_table(paths.protocolsCSV,grid.protocols);
    utils.atomic_write_exact_table(paths.observationsCSV,preparation.observations);
    utils.atomic_write_table(paths.pairedRegistryCSV,grid.pairs);
    utils.atomic_write_table(paths.gridCSV,grid.table);
    utils.atomic_write_table(paths.comparisonsCSV,grid.comparisons);
    utils.atomic_write_table(paths.taskTableCSV,preparation.taskTable);
    utils.atomic_write_table(paths.seedScheduleCSV,preparation.seedScheduleTable);
    utils.atomic_save_struct(paths.preparationMAT,struct('preparation',preparation),'-v7');
    summary=struct('cellCount',grid.cellCount, ...
        'designs',{design_names(grid)}, ...
        'plannedComparisonCount',nnz(grid.comparisons.DesignRole=="primary"), ...
        'completePairsComparisonCount',nnz(grid.comparisons.DesignRole=="complete_pairs"), ...
        'materialCount',numel(unique(grid.table.MaterialCaseID)), ...
        'protocols',{cellstr(grid.protocols.Protocol)}, ...
        'requestSeedCount',numel(preparation.seedRecords), ...
        'taskTable',relative_inside(paths.taskTableCSV,paths.root), ...
        'seedSchedule',relative_inside(paths.seedScheduleCSV,paths.root), ...
        'demonstrationSteps',preparation.aiesPolicy.demonstrationSteps, ...
        'environment',utils.environment_line(), ...
        'preparedUTC',utc_now());
    utils.atomic_write_json(paths.preparationJSON,summary);
end

function preparation=load_preparation(root,cfg)
    paths=campaign_paths(root);
    assert(isfile(paths.preparationMAT), ...
        'confirmation:confirmation_campaign_support:MissingPreparation', ...
        ['No prepared confirmation campaign in %s: run the step ''prepare'' ' ...
         'of run_generalized_study first.'],root);
    saved=load(paths.preparationMAT,'preparation');
    preparation=this_matlab_names(saved.preparation);preparation.paths=paths;
    if nargin>1
        names=fieldnames(preparation.protocolConfigurations);
        for k=1:numel(names)
            preparation.protocolConfigurations.(names{k})=relocate( ...
                preparation.protocolConfigurations.(names{k}),root,cfg);
        end
    end
end

function one=relocate(one,root,cfg)
%RELOCATE A protocol configuration with the folders of this computer.
%   The configurations were written on the computer that prepared the
%   campaign and hold its folders. Every text that starts with the preparing
%   run folder (ONE.native.run) moves to this run folder (ROOT is
%   <run>/_run/confirmation), every other text that starts with the
%   preparing repository (ONE.paths.root) to this repository
%   (CFG.paths.root), with this computer's separators. Nothing else
%   changes: settings, seeds, observations and model are the preparation's.
    oldRun=char(one.native.run);newRun=fileparts(fileparts(char(root)));
    oldRepo=char(one.paths.root);newRepo=char(cfg.paths.root);
    if strcmp(oldRun,newRun)&&strcmp(oldRepo,newRepo),return;end
    one=walk(one);
    function x=walk(x)
        if isstruct(x)
            for i=1:numel(x)
                f=fieldnames(x);
                for j=1:numel(f),x(i).(f{j})=walk(x(i).(f{j}));end
            end
        elseif iscell(x)
            for i=1:numel(x),x{i}=walk(x{i});end
        elseif ischar(x)&&(isrow(x)||isempty(x))
            x=move(x);
        elseif isstring(x)
            for i=1:numel(x),x(i)=string(move(char(x(i))));end
        end
    end
    function value=move(value)
        if below(value,oldRun)
            value=[newRun native(value(numel(oldRun)+1:end))];
        elseif below(value,oldRepo)
            value=[newRepo native(value(numel(oldRepo)+1:end))];
        end
    end
end

function x=this_matlab_names(x)
%THIS_MATLAB_NAMES X with field names that this MATLAB can address.
%   A preparation saved by a newer MATLAB can hold field names longer than
%   an older one allows (namelengthmax; from R2025a a record read from JSON
%   keeps its long keys); the older MATLAB cannot read or set such a field
%   by name. Every longer name is cut to the limit, as that MATLAB's
%   jsondecode cuts a key (made unique if two then agree); nothing else
%   changes, and where every name fits nothing changes at all.
    if isstruct(x)
        names=fieldnames(x);
        long=cellfun(@numel,names)>namelengthmax;
        if any(long)
            names(long)=cellfun(@(n) n(1:namelengthmax),names(long),'UniformOutput',false);
            names=matlab.lang.makeUniqueStrings(names,{},namelengthmax);
            x=cell2struct(struct2cell(x),names,1);
        end
        for i=1:numel(x)
            for j=1:numel(names),x(i).(names{j})=this_matlab_names(x(i).(names{j}));end
        end
    elseif iscell(x)
        for i=1:numel(x),x{i}=this_matlab_names(x{i});end
    end
end

function tf=below(value,prefix)
%BELOW True when VALUE is the folder PREFIX or a path below it.
    tf=~isempty(prefix)&&strncmp(value,prefix,numel(prefix))&& ...
        (numel(value)==numel(prefix)||any(value(numel(prefix)+1)=='/\'));
end

function rest=native(rest)
%NATIVE The rest of a path with this computer's separators.
    rest=strrep(strrep(rest,'\',filesep),'/',filesep);
end

function outcome=cell_outcome(cfg,cellRecord)
%CELL_OUTCOME The saved terminal decision of one cell, or missing.
%   A certified cell has its certified posterior (inversion.save_certified_posterior);
%   an uncertified one its terminal decision at the last level
%   (write_unresolved_decision). OUTCOME has fields missing, certified,
%   terminalState and decision.
    outcome=struct('missing',true,'certified',false,'terminalState','', ...
        'decision',struct([]));
    [artifact,status]=inversion.load_certified_posterior(cfg,cellRecord);
    if status.valid
        outcome.decision=artifact.certification.reliabilityDecision;
        outcome.certified=true;outcome.terminalState='certified';
    else
        paths=inversion.posterior_artifact_paths(cfg,cellRecord,'AIES',1, ...
            cfg.mcmc.levels(end));
        if ~isfile(paths.reliabilityPath),return;end
        outcome.decision=jsondecode(fileread(paths.reliabilityPath));
        outcome.terminalState='unresolved';
    end
    outcome.missing=false;
end

function pathValue=cell_outcome_path(cfg,cellRecord)
    paths=inversion.posterior_artifact_paths(cfg,cellRecord,'AIES',1,cfg.mcmc.levels(1));
    pathValue=fullfile(paths.cellRoot,'cell_outcome.json');
end

function write_cell_outcome(cfg,cellRecord,task,entry)
%WRITE_CELL_OUTCOME The record of a finished cell: its outcome and where it ran.
%   Written last, once the terminal decision is saved; its presence marks
%   the cell as run.
    record=struct('taskIndex',double(task.TaskIndex),'cellID',task.CellID, ...
        'materialCaseID',double(task.MaterialCaseID),'protocol',task.Protocol, ...
        'protocolRole',task.ProtocolRole, ...
        'terminalState',entry.State,'certified',logical(entry.Certified), ...
        'providerReplicateID',entry.ProviderReplicateID, ...
        'providerStepCount',entry.ProviderStepCount,'reason',entry.Reason, ...
        'executionCount',entry.executionCount, ...
        'failedRequestCount',entry.failedRequestCount, ...
        'environment',utils.environment_line(),'finishedUTC',utc_now());
    utils.atomic_write_json(cell_outcome_path(cfg,cellRecord),record,'AllowReplace',true);
end

function pathValue=write_unresolved_decision(cfg,cellRecord,decision)
%WRITE_UNRESOLVED_DECISION The terminal decision of a cell that was not certified.
    paths=inversion.posterior_artifact_paths( ...
        cfg,cellRecord,'AIES',1,decision.stepCount);
    pathValue=paths.reliabilityPath;
    utils.atomic_write_json(pathValue,decision,'AllowReplace',true);
end

function value=campaign_record(cellRecord,decision,evidence)
    certified=logical(decision.certified);
    providerSampler='';providerReplicate=NaN;providerSteps=NaN;
    mechanism='NOT_CERTIFIED';
    if certified
        providerSampler=char(string(decision.provider.sampler));
        providerReplicate=double(decision.provider.replicateID);
        providerSteps=double(decision.provider.stepCount);
        mechanism=char(string(decision.certificationMechanism));
    end
    [count,success,failure,am,identifiers]=evidence_counts(evidence);
    value=struct('ConfirmationCellIndex',cellRecord.cellIndex, ...
        'MaterialCaseID',cellRecord.MaterialCaseID, ...
        'Protocol',cellRecord.protocol, ...
        'ProtocolRole',cellRecord.protocolRole, ...
        'Certified',certified,'State',char(string(decision.status)), ...
        'ProviderSampler',providerSampler, ...
        'ProviderReplicateID',providerReplicate, ...
        'ProviderStepCount',providerSteps, ...
        'Reason',char(string(decision.reason)), ...
        'CertificationMechanism',mechanism, ...
        'executionCount',count,'successfulRequestCount',success, ...
        'failedRequestCount',failure,'amRequestCount',am, ...
        'SamplerFailureIdentifiers',identifiers);
end

function [count,success,failure,am,identifiers]=evidence_counts(evidence)
    if isempty(evidence)
        count=0;success=0;failure=0;am=0;identifiers='';return
    end
    if isfield(evidence,'succeeded')
        ok=logical([evidence.succeeded]);samplers={evidence.sampler};ids={};
        for i=find(~ok),ids{end+1}=evidence(i).failure.exceptionIdentifier;end %#ok<AGROW>
    else
        ok=logical([evidence.executionSucceeded]);
        samplers=cellstr(string({evidence.sampler}));
        ids=cellstr(string({evidence(~ok).failureIdentifier}));
    end
    count=numel(evidence);success=nnz(ok);failure=nnz(~ok);
    am=nnz(strcmp(samplers,'AM'));identifiers=strjoin(unique(ids,'stable'),';');
end

function T=certification_table(entries)
    T=table([entries.ConfirmationCellIndex].',[entries.MaterialCaseID].', ...
        string({entries.Protocol}).',string({entries.ProtocolRole}).', ...
        logical([entries.Certified]).',string({entries.State}).', ...
        string({entries.ProviderSampler}).',[entries.ProviderReplicateID].', ...
        [entries.ProviderStepCount].',string({entries.Reason}).', ...
        string({entries.CertificationMechanism}).', ...
        [entries.executionCount].',[entries.successfulRequestCount].', ...
        [entries.failedRequestCount].',[entries.amRequestCount].', ...
        string({entries.SamplerFailureIdentifiers}).', ...
        'VariableNames',{'ConfirmationCellIndex','MaterialCaseID','Protocol', ...
        'ProtocolRole','Certified','State','ProviderSampler','ProviderReplicateID', ...
        'ProviderStepCount','Reason','CertificationMechanism','ExecutionCount', ...
        'SuccessfulRequestCount','FailedRequestCount','AMRequestCount', ...
        'SamplerFailureIdentifiers'});
end

function report=confirmation_report(grid,summaries,elapsed)
%CONFIRMATION_REPORT The Markdown report of a compared campaign: its protocols, then per observation design its cells and comparisons.
%   SUMMARIES: one summary per design of GRID.designs, in order
%   (confirmation.summarize_confirmation).
    selected=grid.protocols(grid.protocols.ProtocolRole=="selected",:);
    if ~iscell(summaries),summaries={summaries};end
    report=sprintf([ ...
        '# Confirmation of the protocol screening\n\n' ...
        '- Reference protocol: %s\n' ...
        '- Selected protocols: %s\n' ...
        '- Materials (direct COMSOL observations): %d\n'], ...
        grid.protocols.Protocol(1),strjoin(selected.Protocol+" ("+selected.ObjectiveID+")",', '), ...
        numel(unique(grid.table.MaterialCaseID)));
    for d=1:numel(grid.designs)
        one=grid.designs(d);sub=design_grid(grid,one.name);S=summaries{d};
        title=sprintf('Observation design %s',one.name);
        if strcmp(one.role,'complete_pairs')
            title=sprintf(['Observation design %s on the complete pairs (descriptive, not ' ...
                'representative of the protocols)'],one.name);
        end
        report=[report sprintf([ ...
            '\n## %s\n\n' ...
            '- Inverse cells: %d\n' ...
            '- Certified cells: %d\n' ...
            '- Unresolved cells (sampled, not certified): %d\n' ...
            '- Cells without an accepted observation (not sampled): %d\n' ...
            '- Material/protocol comparisons with both posteriors (certified or healthy fallback): ' ...
            '%d of %d; both cells certified: %d\n'], ...
            title,sub.cellCount,S.certifiedCellCount,S.unresolvedCellCount, ...
            S.noObservationCellCount,S.pairedCount,height(sub.comparisons), ...
            S.pairedCertifiedCount)]; %#ok<AGROW>
    end
    report=[report sprintf('\n- Elapsed seconds: %.6f\n- Environment: %s\n',elapsed, ...
        utils.environment_line())];
end

function policy=portable_policy(value)
    policy=rmfield(value,intersect(fieldnames(value), ...
        {'enabled','observationsFile','rankingsFile','outputRoot', ...
        'maximumRepresentativeOverlayPairs','showcase'}));
end

function relative=relative_inside(pathValue,root)
    pathValue=utils.absolute_path(pathValue);root=utils.absolute_path(root);
    relative=strrep(pathValue(numel(root)+2:end),'\','/');
end

function value=utc_now()
    value=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss''Z'''));
end
