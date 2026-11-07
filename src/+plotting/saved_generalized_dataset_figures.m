function manifest=saved_generalized_dataset_figures(cfg,selectedPath,caseRegistryPath)
%SAVED_GENERALIZED_DATASET_FIGURES The figures of the generalized dataset.
%   MANIFEST = plotting.saved_generalized_dataset_figures(CFG, SELECTEDPATH,
%   CASEREGISTRYPATH) draws, from the saved selected-case table
%   SELECTEDPATH and the case registry CASEREGISTRYPATH, the input
%   distributions, the case completeness and the support of the protocol
%   space, and returns the manifest.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    assert(strcmp(cfg.dataMode,'real_extended')&&isfile(selectedPath)&& ...
        isfile(caseRegistryPath), ...
        'plotting:saved_generalized_dataset_figures:Inputs', ...
        ['The generalized dataset figures need the generalized route and the saved ' ...
         'tables %s and %s; rerun the step ''dataset''.'],selectedPath,caseRegistryPath);
    plotting.style();
    selected=readtable(selectedPath,'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    cases=readtable(caseRegistryPath,'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    names=cfg.realExtended.learningInputNames;
    assert(all(ismember([names {'split_role'}], ...
        selected.Properties.VariableNames))&& ...
        ismember('pair_status',cases.Properties.VariableNames), ...
        'plotting:saved_generalized_dataset_figures:Schema', ...
        ['The saved dataset tables lack the input, split_role or pair_status ' ...
         'columns; rerun the step ''dataset''.']);
    parts=cell(3,1);
    parts{1}=input_distribution(selected,names,cfg,selectedPath);
    parts{2}=protocol_support(selected,cfg,selectedPath);
    parts{3}=completeness_status(cases,cfg,caseRegistryPath);
    manifest=vertcat(parts{:});
end

function row=input_distribution(T,names,cfg,source)
    fig=figure('Position',[50 50 1200 720]);
    tiledlayout(2,4,'Padding','compact','TileSpacing','compact');
    train=T.split_role=="train";heldout=T.split_role=="test";
    for j=1:numel(names)
        nexttile;hold on;
        histogram(double(T{train,names{j}}),'Normalization','probability', ...
            'FaceAlpha',0.55);
        histogram(double(T{heldout,names{j}}),'Normalization','probability', ...
            'FaceAlpha',0.55);
        title(names{j},'Interpreter','none');ylabel('fraction');
    end
    legend({'development','internal held-out'},'Location','southoutside', ...
        'Orientation','horizontal');
    sgtitle('Generalized complete-case input distributions');
    row=export_stage1(fig,cfg,'input_distributions',{source},'publication');
end

function row=protocol_support(T,cfg,source)
    fig=figure('Position',[80 80 1000 450]);
    roles=["train" "test"];titles=["development" "internal held-out"];
    for r=1:2
        subplot(1,2,r);take=T.split_role==roles(r);
        scatter(double(T.log10_abs_suction_rate(take)), ...
            double(T.hold_dur_s(take)),34,double(T.pause_dur_s(take)), ...
            'filled');colorbar;
        xlabel('log10 absolute suction rate [kPa/s]');ylabel('hold duration [s]');
        title(titles(r));
    end
    sgtitle('Protocol-space support; colour = pause duration [s]');
    row=export_stage1(fig,cfg,'protocol_space_support',{source},'aggregate');
end

function row=completeness_status(T,cfg,source)
    values=string(T.pair_status);[groups,~,index]=unique(values,'stable');
    counts=accumarray(index,1);
    fig=figure('Position',[80 80 1100 480]);bar(counts);
    xticks(1:numel(groups));xticklabels(groups);xtickangle(25);
    ylabel('CaseID count');title('Generalized campaign pair-status inventory');
    row=export_stage1(fig,cfg,'case_completeness_status',{source},'aggregate');
end

function row=export_stage1(fig,cfg,name,sources,scope)
    local=cfg;local.paths.stage07=cfg.paths.datasetFigures;
    row=plotting.export_saved_figure(fig,local,'dataset',name,sources,scope,[]);
end
