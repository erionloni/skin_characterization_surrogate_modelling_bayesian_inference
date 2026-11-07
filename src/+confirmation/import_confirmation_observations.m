function result=import_confirmation_observations(cfg,design,exportCSV,provenanceJSON,acceptanceJSON,outputRoot)
%IMPORT_CONFIRMATION_OBSERVATIONS Accept the reviewed COMSOL observations of the confirmation design.
%   RESULT = confirmation.import_confirmation_observations(CFG, DESIGN,
%   EXPORTCSV, PROVENANCEJSON, ACCEPTANCEJSON, OUTPUTROOT) reads
%     EXPORTCSV       the reviewed COMSOL export, one row per solve: its
%                     COMSOL inputs (confirmation.comsol_inputs, 17
%                     significant digits), Probe (D2 or D6), the probe's
%                     three closing pressures in mbar (pcl1_mbar, pcl2_mbar,
%                     pcl3_mbar: cycles 1 to 3), their QC (QCValid_pcl1 to
%                     QCValid_pcl3: 1 or 0; QCReason_pcl1 to QCReason_pcl3:
%                     the reason of a pressure that fails QC) and the solve's
%                     status in COMSOL (SolveStatus);
%     PROVENANCEJSON  the COMSOL provenance (text fields comsol_model,
%                     geometry, swelling, protocol_definition,
%                     closing_pressure_extraction);
%     ACCEPTANCEJSON  the reviewer's acceptance (decision
%                     ACCEPT_DIRECT_OBSERVATIONS, reviewedBy, reviewedUTC,
%                     and optionally excludedDesignRows: the design rows the
%                     reviewer accepts as missing, each with MaterialCaseID,
%                     Protocol and reason, e.g. a probe pair that failed);
%   joins every solve to the solve of the design DESIGN
%   (confirmation.confirmation_design) with exactly the same inputs and
%   probe (confirmation.join_by_values: no ID), and writes to OUTPUTROOT (a
%   new folder) copies of the three inputs, observation_qc.csv: per
%   design row, the QC-valid pressures of each probe, the solve statuses,
%   the reasons of the pressures that fail QC and the reviewer's exclusion,
%   and comsol_outcomes.csv: per protocol and probe, how its solves ended in
%   COMSOL (their SolveStatus: completed, solved_phase9; an early stop with
%   the phase it stopped in, early_stop_phase<N>; nonlinear_failure; not
%   run, not_recorded; any other status by name).
%   A design row is accepted when the pressures of the confirmation's
%   observation design (CFG.stage9bConfirmation.design, settings B.7:
%   d2_only the three D2 pressures, all_six the six) are QC-valid and the
%   reviewer did not exclude it.
%   When every other row is excluded by the reviewer, it also writes the
%   accepted observations, confirmation_observations.csv: one row per
%   design row, in design order, with MaterialCaseID, Protocol, the COMSOL
%   inputs, the QC-valid closing pressures (CFG.realExtended.outputNames;
%   NaN where QC failed), the status of both solves, the COMSOL model,
%   Accepted (1 or 0) and the reviewer's ExclusionReason: an excluded row is
%   never imputed; its cells are unavailable. Otherwise it stops and lists
%   the design rows that lack pressures and are not excluded (the QC table
%   stays for the review).
%   Refused before anything is written: an incomplete acceptance or
%   provenance record, an export without the required columns, a solve
%   that matches no design solve, a design solve given twice or not at all,
%   a QC flag other than 0 or 1, a QC-valid pressure that is not finite and
%   positive, a pressure that fails QC without a reason, an excluded row
%   that is not a design row, is named twice or has no reason.
%   The pressures are copied: no extraction, interpolation, simulation or
%   sampling.
%   RESULT: planned and accepted design rows, and the accepted table.
%   Side effects: writes OUTPUTROOT.
%   Computation: seconds.

    assert(~isfolder(outputRoot),'confirmation:import_confirmation_observations:OutputExists', ...
        'The accepted observations are written to a new folder; %s exists.',outputRoot);
    acceptance=read_record(acceptanceJSON,{'decision','reviewedBy','reviewedUTC'}, ...
        'The acceptance record');
    assert(strcmp(char(string(acceptance.decision)),'ACCEPT_DIRECT_OBSERVATIONS'), ...
        'confirmation:import_confirmation_observations:Acceptance', ...
        ['%s does not accept the observations: its decision must be ACCEPT_DIRECT_OBSERVATIONS, ' ...
         'recorded with the reviewer and the time once the COMSOL results were reviewed.'], ...
        acceptanceJSON);
    provenance=read_record(provenanceJSON,{'comsol_model','geometry','swelling', ...
        'protocol_definition','closing_pressure_extraction'},'The COMSOL provenance');

    inputs=confirmation.comsol_inputs();
    pressures={'pcl1_mbar','pcl2_mbar','pcl3_mbar'};
    flags={'QCValid_pcl1','QCValid_pcl2','QCValid_pcl3'};
    reasons={'QCReason_pcl1','QCReason_pcl2','QCReason_pcl3'};
    T=confirmation.read_exact_table(exportCSV,[inputs pressures]);
    required=[inputs {'Probe'} pressures flags reasons {'SolveStatus'}];
    missing=required(~ismember(required,T.Properties.VariableNames));
    assert(isempty(missing),'confirmation:import_confirmation_observations:Columns', ...
        'The export %s lacks the columns: %s.',exportCSV,strjoin(missing,', '));
    solves=design.solves;
    at=confirmation.join_by_values(solves,T,[inputs {'Probe'}],solves.RunID,exportCSV);
    valid=false(height(T),3);
    for c=1:3
        flag=strtrim(T.(flags{c}));
        assert(all(ismember(flag,["0","1"])),'confirmation:import_confirmation_observations:Flag', ...
            'The QC flags %s of %s must be 0 or 1 in every row.',flags{c},exportCSV);
        valid(:,c)=flag=="1";
        value=T.(pressures{c});
        bad=find(valid(:,c)&~(isfinite(value)&value>0));
        assert(isempty(bad),'confirmation:import_confirmation_observations:Pressure', ...
            'The QC-valid pressures %s of %s must be finite and positive (solves %s).', ...
            pressures{c},exportCSV,strjoin(solves.RunID(at(bad)),', '));
        silent=find(~valid(:,c)&strlength(strtrim(T.(reasons{c})))==0);
        assert(isempty(silent),'confirmation:import_confirmation_observations:Reason', ...
            'A pressure that fails QC needs its reason in %s of %s (solves %s).', ...
            reasons{c},exportCSV,strjoin(solves.RunID(at(silent)),', '));
    end

    % The six pressures of every design row: D2, then D6, cycles 1 to 3.
    outputs=cellstr(string(cfg.realExtended.outputNames));
    rows=design.rows;n=height(rows);
    Y=nan(n,6);ok=false(n,6);status=strings(n,2);notes=strings(n,1);counts=zeros(n,2);
    probes=["D2","D6"];
    for i=1:height(T)
        solve=solves(at(i),:);d=solve.DesignIndex;p=find(probes==solve.Probe);
        status(d,p)=T.SolveStatus(i);
        counts(d,p)=nnz(valid(i,:));
        for c=1:3
            j=find(strcmp(outputs,sprintf('pcl%d_%s_mbar',c,probes(p))));
            assert(isscalar(j),'confirmation:import_confirmation_observations:Outputs', ...
                'The outputs of the route (settings B.1) lack pcl%d_%s_mbar.',c,probes(p));
            ok(d,j)=valid(i,c);
            if valid(i,c)
                Y(d,j)=T.(pressures{c})(i);
            else
                notes(d)=strjoin([notes(d) sprintf("%s: %s",outputs{j},strtrim(T.(reasons{c})(i)))],'; ');
            end
        end
    end
    notes=regexprep(notes,'^; ','');
    % The pressures of the confirmation's observation design (settings B.7).
    required=confirmation_outputs(cfg,outputs);
    complete=all(ok(:,required),2);
    exclusion=excluded_rows(acceptance,rows,acceptanceJSON);
    excluded=strlength(exclusion)>0;
    accepted=complete&~excluded;
    qc=[rows(:,{'DesignIndex','MaterialCaseID','Protocol'}),table(counts(:,1),counts(:,2), ...
        status(:,1),status(:,2),complete,excluded,accepted,notes,exclusion,'VariableNames', ...
        {'ValidPressures_D2','ValidPressures_D6','SolveStatus_D2','SolveStatus_D6', ...
        'CompleteForDesign','Excluded','Accepted','Reasons','ExclusionReason'})];
    mkdir(outputRoot);
    copyfile(exportCSV,fullfile(outputRoot,'reviewed_export.csv'));
    copyfile(provenanceJSON,fullfile(outputRoot,'source_provenance.json'));
    copyfile(acceptanceJSON,fullfile(outputRoot,'direct_data_acceptance.json'));
    qcPath=fullfile(outputRoot,'observation_qc.csv');
    utils.atomic_write_table(qcPath,qc);
    utils.atomic_write_table(fullfile(outputRoot,'comsol_outcomes.csv'),comsol_outcomes(rows,status));
    lacking=find(~complete&~excluded);
    labels="case"+string(rows.MaterialCaseID(lacking))+"_"+rows.Protocol(lacking);
    assert(isempty(lacking),'confirmation:import_confirmation_observations:Incomplete', ...
        ['%d of the %d design rows lack QC-valid pressures of the observation design (%s): %s. ' ...
         'The observations are not accepted; the QC of every design row is in %s. A row the ' ...
         'reviewer accepts as missing is named, with the reason, in excludedDesignRows of the ' ...
         'acceptance record (its cells are then unavailable; nothing is imputed).'], ...
        numel(lacking),n,strjoin(outputs(required),', '),strjoin(labels(1:min(end,10)),', '),qcPath);
    observations=[rows(:,[{'MaterialCaseID','Protocol'} inputs]),array2table(Y,'VariableNames',outputs), ...
        table(status(:,1),status(:,2),repmat(string(provenance.comsol_model),n,1),double(accepted), ...
        exclusion,'VariableNames',{'SolveStatus_D2','SolveStatus_D6','COMSOLModel','Accepted', ...
        'ExclusionReason'})];
    tablePath=fullfile(outputRoot,'confirmation_observations.csv');
    utils.atomic_write_exact_table(tablePath,observations);
    result=struct('planned',n,'accepted',nnz(accepted),'excluded',nnz(excluded), ...
        'observations',tablePath);
end

function T=comsol_outcomes(rows,status)
%COMSOL_OUTCOMES Per protocol and probe: how its solves ended in COMSOL (their SolveStatus).
    protocols=unique(rows.Protocol,'stable');probes=["D2","D6"];
    parts=cell(numel(protocols),2);
    for i=1:numel(protocols)
        for k=1:2
            s=strtrim(status(rows.Protocol==protocols(i),k));
            phase=regexp(cellstr(s),'^early_stop_phase(\d+)$','tokens','once');
            early=~cellfun(@isempty,phase);
            phases=unique(string(cellfun(@(t) t{1},phase(early),'UniformOutput',false)));
            known=s=="solved_phase9"|early|s=="nonlinear_failure"|s=="not_recorded"|s=="";
            parts{i,k}=table(protocols(i),probes(k),numel(s),nnz(s=="solved_phase9"), ...
                nnz(early),join_text(phases),nnz(s=="nonlinear_failure"), ...
                nnz(s=="not_recorded"|s==""),nnz(~known),join_text(unique(s(~known))), ...
                'VariableNames',{'Protocol','Probe','Solves','Completed','EarlyStop', ...
                'EarlyStopPhase','NonlinearFailure','NotRun','Other','OtherStatus'});
        end
    end
    T=vertcat(parts{:});
end

function text=join_text(values)
%JOIN_TEXT The values separated by ';' ("" for none).
    text="";
    if ~isempty(values),text=strjoin(string(values(:)).',';');end
end

function required=confirmation_outputs(cfg,outputs)
%CONFIRMATION_OUTPUTS The indices, among OUTPUTS, of the pressures of the confirmation's observation design.
    design=inversion.design_registry(cfg.stage9bConfirmation.design);
    required=reshape(double(design.sourceOutputIndices),1,[]);
    assert(~isempty(required)&&all(required>=1&required<=numel(outputs)), ...
        'confirmation:import_confirmation_observations:Design', ...
        'The observation design %s names no pressures of the route.',design.name);
end

function reason=excluded_rows(acceptance,rows,acceptanceJSON)
%EXCLUDED_ROWS The reviewer's reason for every design row the acceptance excludes ("" for the others).
    reason=strings(height(rows),1);
    if ~isfield(acceptance,'excludedDesignRows')||isempty(acceptance.excludedDesignRows)
        return;
    end
    listed=acceptance.excludedDesignRows;
    if iscell(listed),listed=[listed{:}];end
    assert(isstruct(listed)&&all(isfield(listed,{'MaterialCaseID','Protocol','reason'})), ...
        'confirmation:import_confirmation_observations:Excluded', ...
        'excludedDesignRows of %s must list objects with MaterialCaseID, Protocol and reason.', ...
        acceptanceJSON);
    for k=1:numel(listed)
        hit=find(double(rows.MaterialCaseID)==double(listed(k).MaterialCaseID)& ...
            rows.Protocol==string(listed(k).Protocol));
        text=strtrim(string(listed(k).reason));
        assert(isscalar(hit)&&isscalar(text)&&strlength(text)>0&&strlength(reason(hit))==0, ...
            'confirmation:import_confirmation_observations:Excluded', ...
            ['excludedDesignRows of %s: material %g with protocol %s is not a design row, is ' ...
             'named twice or has no reason.'],acceptanceJSON,double(listed(k).MaterialCaseID), ...
            string(listed(k).Protocol));
        reason(hit)=text;
    end
end

function record=read_record(pathValue,fields,what)
%READ_RECORD A JSON record whose FIELDS are all given as text.
    record=jsondecode(fileread(pathValue));
    missing=fields(~isfield(record,fields));
    assert(isstruct(record)&&isempty(missing),'confirmation:import_confirmation_observations:Record', ...
        '%s %s lacks: %s.',what,pathValue,strjoin(missing,', '));
    for k=1:numel(fields)
        value=string(record.(fields{k}));
        assert(isscalar(value)&&~ismissing(value)&&strlength(strtrim(value))>0&& ...
            ~ismember(upper(strtrim(value)),["UNKNOWN","UNAVAILABLE","NOT_RECORDED","PENDING"]), ...
            'confirmation:import_confirmation_observations:Record', ...
            'The field %s of %s %s is empty or unresolved.',fields{k},lower(what),pathValue);
    end
end
