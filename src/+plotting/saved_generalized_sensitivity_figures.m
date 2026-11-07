function manifest=saved_generalized_sensitivity_figures(cfg,extendedTableRoot)
%SAVED_GENERALIZED_SENSITIVITY_FIGURES The figures of the generalized sensitivity.
%   MANIFEST = plotting.saved_generalized_sensitivity_figures(CFG,
%   EXTENDEDTABLEROOT) draws, from the saved sensitivity tables below
%   EXTENDEDTABLEROOT, the figures of plotting.saved_sensitivity_figures, the
%   material and protocol groups, the protocol-variable sensitivity and the
%   support classification, and returns the manifest. The material x
%   protocol second-order indices (gp_theta_phi_second_order_interactions.csv)
%   are not drawn: a mean over the outputs would mix their offsets.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    assert(strcmp(cfg.dataMode,'real_extended')&&isfolder(extendedTableRoot), ...
        'plotting:saved_generalized_sensitivity_figures:Inputs', ...
        ['The generalized sensitivity figures need the generalized route and the ' ...
         'saved tables in %s; rerun the step ''sensitivity''.'],extendedTableRoot);
    plotting.style();local=cfg;
    local.paths.stage07=cfg.paths.sensitivityFigures;
    common=plotting.saved_sensitivity_figures(local,struct('Mode','aggregate'));
    parts={common};
    groupPath=fullfile(extendedTableRoot,'gp_material_protocol_group_summary.csv');
    protocolPath=fullfile(extendedTableRoot,'gp_protocol_variable_sensitivity.csv');
    supportPath=fullfile(extendedTableRoot,'support_extrapolation_summary.csv');
    if isfile(groupPath),parts{end+1}=group_figure(groupPath,local);end
    if isfile(protocolPath),parts{end+1}=protocol_figure(protocolPath,local);end
    if isfile(supportPath),parts{end+1}=support_figure(supportPath,local);end
    manifest=vertcat(parts{:});
end

function row=group_figure(path,cfg)
    T=readtable(path,'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    required={'output','material_first_order_sum','protocol_first_order_sum', ...
        'mean_material_total_order','mean_protocol_total_order'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_generalized_sensitivity_figures:GroupSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''sensitivity''.', ...
        char(string(path)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    values=[double(T.material_first_order_sum) ...
        double(T.protocol_first_order_sum) double(T.mean_material_total_order) ...
        double(T.mean_protocol_total_order)];
    fig=figure('Position',[80 80 1100 500]);bar(values);
    xticks(1:height(T));xticklabels(T.output);xtickangle(20);
    ylabel('Sobol summary');legend({'material first-order sum', ...
        'protocol first-order sum','mean material total-order', ...
        'mean protocol total-order'},'Location','southoutside', ...
        'Orientation','horizontal');
    title('GP material/protocol sensitivity summaries');
    row=plotting.export_saved_figure(fig,cfg,'sensitivity', ...
        'gp_material_protocol_groups',{path},'aggregate',[]);
end

function row=protocol_figure(path,cfg)
    T=readtable(path,'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    outputs=unique(T.output,'stable');inputs=unique(T.protocol_input,'stable');
    values=nan(numel(outputs),numel(inputs));
    for o=1:numel(outputs)
        for p=1:numel(inputs)
            take=T.output==outputs(o)&T.protocol_input==inputs(p);
            if nnz(take)==1,values(o,p)=double(T.total_order(take));end
        end
    end
    row=heatmap(values,inputs,outputs,'GP protocol-input total-order Sobol', ...
        'gp_protocol_variable_sensitivity',path,cfg);
end

function row=support_figure(path,cfg)
    T=readtable(path,'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    fig=figure('Position',[80 80 1000 450]);bar(100*double(T.fraction));
    xticks(1:height(T));xticklabels(T.support_class);xtickangle(25);
    ylabel('Sobol-domain probe fraction [%]');
    title('Generalized full-box support classification');
    row=plotting.export_saved_figure(fig,cfg,'sensitivity', ...
        'generalized_support_classification',{path},'aggregate',[]);
end

function row=heatmap(values,xlabels,ylabels,titleText,name,path,cfg)
    fig=figure('Position',[80 80 950 540]);imagesc(values);colorbar;
    xticks(1:numel(xlabels));xticklabels(xlabels);xtickangle(20);
    yticks(1:numel(ylabels));yticklabels(ylabels);title(titleText);
    for r=1:size(values,1)
        for c=1:size(values,2)
            text(c,r,sprintf('%.3f',values(r,c)), ...
                'HorizontalAlignment','center','FontSize',8);
        end
    end
    row=plotting.export_saved_figure(fig,cfg,'sensitivity',name,{path}, ...
        'aggregate',[]);
end
