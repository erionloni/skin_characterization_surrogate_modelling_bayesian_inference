function result = run_fixed(cfg)
%RUN_FIXED Global sensitivity of the fixed route's six closing pressures.
%   RESULT = sensitivity.run_fixed(CFG) computes, with the seed CFG.seed and
%   the GP and PCE of CFG.files.gp and CFG.files.pce, the GP first- and
%   total-order Sobol indices (primary) and, as supporting analyses, the PCE
%   analytic Sobol indices, second-order indices, interaction gaps,
%   ratio-output Sobol indices and ARD importance. It writes
%   CFG.files.sensitivity and the tables below CFG.paths.sensitivityTables
%   (primary/, supporting/). RESULT names the saved artifact and the
%   correlation of ARD importance with the total Sobol indices.
%   The body of the pre-publication script
%   (s03_run_sensitivity), moved unchanged.
%   Computation: about 2 minutes (UQLab predictions).
%   Side effects: writes the files above; the random number generator's
%   state is restored afterwards.
    assert(strcmp(cfg.dataMode,'real'),'sensitivity:run_fixed:Route', ...
        'sensitivity.run_fixed analyses the fixed route''s surrogates.');
    state=rng;restore=onCleanup(@()rng(state));
    rng(cfg.seed,'twister');
    ensure_dirs({fullfile(cfg.paths.sensitivityTables,'primary'), ...
        fullfile(cfg.paths.sensitivityTables,'supporting')});
    require_files({cfg.files.gp,cfg.files.pce,cfg.files.dataset});
    P=parameters.parameter_space(cfg);
    savedGP=load(cfg.files.gp,'gp');savedPCE=load(cfg.files.pce,'pce');
    gp=savedGP.gp;pce=savedPCE.pce;

    [SfGP,StGP,S2GP]=sensitivity.sobol(gp,P,cfg);
    [SfPCE,StPCE,S2PCE]=sensitivity.pce_sobol_analytic(pce,P,cfg);
    [~,RtGP,ratioNames]=sensitivity.ratio_sobol(gp,P,cfg);
    [~,RtPCE]=sensitivity.ratio_sobol(pce,P,cfg);
    A=sensitivity.ard(gp,P);
    ardSobolCorr=utils.pearson_correlation( ...
        A.meanImportance(:),mean(StGP,1).');
    GapGP=max(StGP-SfGP,0);GapPCE=max(StPCE-SfPCE,0);
    sanity_check(SfGP,StGP,S2GP,SfPCE,StPCE,S2PCE,cfg.sobol.consistencyTol);

    payload=struct('SfGP',SfGP,'StGP',StGP,'S2GP',S2GP,'GapGP',GapGP, ...
        'SfPCE',SfPCE,'StPCE',StPCE,'S2PCE',S2PCE,'GapPCE',GapPCE, ...
        'RtGP',RtGP,'RtPCE',RtPCE,'ratioNames',{ratioNames}, ...
        'A',A,'ardSobolCorr',ardSobolCorr, ...
        'primaryAnalysis','GP first-order and total-order Sobol', ...
        'supportingAnalyses',{{'PCE analytic Sobol','second-order Sobol', ...
        'interaction gap','ratio sensitivity','ARD importance'}});
    utils.atomic_save_struct(cfg.files.sensitivity,payload,'-v7.3');

    primary=fullfile(cfg.paths.sensitivityTables,'primary');
    supporting=fullfile(cfg.paths.sensitivityTables,'supporting');
    write_matrix(SfGP,P.outputNames,P.names,fullfile(primary,'sobol_gp_first.csv'));
    write_matrix(StGP,P.outputNames,P.names,fullfile(primary,'sobol_gp_total.csv'));
    write_pairs(S2GP,P.outputNames,fullfile(supporting,'sobol_gp_second_order.csv'));
    write_matrix(GapGP,P.outputNames,P.names, ...
        fullfile(supporting,'sobol_gp_interaction_gap.csv'));
    % One canonical set of PCE analytic tables: no duplicate aliases.
    write_matrix(SfPCE,P.outputNames,P.names, ...
        fullfile(supporting,'sobol_pce_analytic_first.csv'));
    write_matrix(StPCE,P.outputNames,P.names, ...
        fullfile(supporting,'sobol_pce_analytic_total.csv'));
    write_pairs(S2PCE,P.outputNames, ...
        fullfile(supporting,'sobol_pce_analytic_second_order.csv'));
    write_matrix(GapPCE,P.outputNames,P.names, ...
        fullfile(supporting,'sobol_pce_interaction_gap.csv'));
    write_matrix(RtGP,ratioNames,P.names, ...
        fullfile(supporting,'ratio_sobol_gp_total.csv'));
    write_matrix(RtPCE,ratioNames,P.names, ...
        fullfile(supporting,'ratio_sobol_pce_total.csv'));
    write_matrix(A.importance,P.outputNames,P.names, ...
        fullfile(supporting,'ard_importance.csv'));

    result=struct('artifact',cfg.files.sensitivity,'ard_sobol_correlation',ardSobolCorr);
    fprintf('[sensitivity] primary GP Sobol and supporting sensitivity analyses complete.\n');
end

function write_matrix(value,rows,columns,path)
    T=array2table(value,'VariableNames',matlab.lang.makeValidName(columns), ...
        'RowNames',cellstr(string(rows)));
    utils.atomic_write_table(path,T,'WriteRowNames',true);
end

function write_pairs(value,rows,path)
    T=array2table(value.indices, ...
        'VariableNames',matlab.lang.makeValidName(value.pairLabels), ...
        'RowNames',cellstr(string(rows)));
    utils.atomic_write_table(path,T,'WriteRowNames',true);
end

function sanity_check(SfGP,StGP,S2GP,SfPCE,StPCE,S2PCE,tol)
    if any(SfGP(:)>StGP(:)+tol)||any(SfPCE(:)>StPCE(:)+tol)
        warning('sensitivity:run_fixed:FirstExceedsTotal', ...
            'Some first-order estimates exceed total-order by more than %g.',tol);
    end
    if any([SfGP(:);StGP(:);S2GP.indices(:);SfPCE(:);StPCE(:); ...
            S2PCE.indices(:)] < -tol)
        warning('sensitivity:run_fixed:NegativeIndex', ...
            'Some sensitivity estimates are below -%g.',tol);
    end
end

function require_files(paths)
    for i=1:numel(paths),assert(isfile(paths{i}), ...
        'sensitivity:run_fixed:MissingInput','Missing input: %s',paths{i});end
end

function ensure_dirs(paths)
    for i=1:numel(paths),if ~isfolder(paths{i}),mkdir(paths{i});end,end
end
