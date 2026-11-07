function manifest = saved_sensitivity_figures(cfg,options)
%SAVED_SENSITIVITY_FIGURES The figures of the fixed sensitivity, from its saved tables.
%   MANIFEST = plotting.saved_sensitivity_figures(CFG, OPTIONS) draws, from the
%   saved Sobol and ARD tables (no Sobol computation), the GP and PCE total
%   indices, the second-order indices and the interaction gaps, the
%   ratio-feature indices and the ARD importance (no figure averages the
%   indices over the outputs),
%   and returns the manifest. The generalized route (also drawn by
%   plotting.saved_generalized_sensitivity_figures) leaves out the PCE's
%   ratio-feature indices.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    root=study.source_folder(cfg,'sensitivity');parts={};
    primary=fullfile(root,'primary');supporting=fullfile(root,'supporting');
    totalPath=fullfile(primary,'sobol_gp_total.csv');
    firstPath=fullfile(primary,'sobol_gp_first.csv');
    if isfile(totalPath)&&isfile(firstPath)
        [total,outputs,names]=read_matrix(totalPath);
        parts{end+1}=heatmap_figure(total,names,outputs, ...
            'GP total-order Sobol indices','gp_total_sobol',cfg, ...
            {totalPath},'publication');
    end
    if ~strcmp(options.Mode,'publication')
        pceTotalPath=fullfile(supporting,'sobol_pce_analytic_total.csv');
        if isfile(pceTotalPath)
            [pceTotal,pceOutputs,pceNames]=read_matrix(pceTotalPath);
            parts{end+1}=heatmap_figure(pceTotal,pceNames,pceOutputs, ...
                'PCE analytic total-order Sobol','pce_total_sobol',cfg, ...
                {pceTotalPath},'aggregate');
        end
        parts=append_matrix(parts,fullfile(supporting, ...
            'sobol_gp_interaction_gap.csv'),'GP Sobol interaction gap', ...
            'gp_interaction_gap',cfg);
        parts=append_matrix(parts,fullfile(supporting, ...
            'sobol_pce_interaction_gap.csv'),'PCE Sobol interaction gap', ...
            'pce_interaction_gap',cfg);
        parts=append_matrix(parts,fullfile(supporting,'ard_importance.csv'), ...
            'GP ARD importance (supporting)','ard_importance',cfg);
        parts=append_matrix(parts,fullfile(supporting, ...
            'ratio_sobol_gp_total.csv'),'GP ratio-feature total Sobol', ...
            'ratio_sobol_gp_total',cfg);
        % Not for the generalized route: its PCE takes the D6 denominator to
        % zero in corners of the box, and its ratio indices are not drawn
        % (the analysis README, study.analyses).
        if ~strcmp(cfg.dataMode,'real_extended')
            parts=append_matrix(parts,fullfile(supporting, ...
                'ratio_sobol_pce_total.csv'),'PCE ratio-feature total Sobol', ...
                'ratio_sobol_pce_total',cfg);
        end
        parts=append_matrix(parts,fullfile(supporting, ...
            'sobol_gp_second_order.csv'),'GP second-order Sobol', ...
            'gp_second_order_sobol',cfg);
        parts=append_matrix(parts,fullfile(supporting, ...
            'sobol_pce_analytic_second_order.csv'), ...
            'PCE analytic second-order Sobol','pce_second_order_sobol',cfg);
    end
    manifest=combine(parts);
end

function parts=append_matrix(parts,path,titleText,name,cfg)
    if ~isfile(path),return;end
    [values,rows,columns]=read_matrix(path);
    parts{end+1}=heatmap_figure(values,columns,rows,titleText,name,cfg, ...
        {path},'aggregate');
end

function [matrix,rowNames,columnNames]=read_matrix(path)
    T=readtable(path,'Delimiter',',','TextType','string','VariableNamingRule','preserve');
    assert(width(T)>=2,'plotting:saved_sensitivity_figures:MatrixSchema', ...
        ['The saved sensitivity table %s needs a name column and at least one value ' ...
         'column; rerun the step ''sensitivity''.'],path);
    firstName=T.Properties.VariableNames{1};
    rowNames=string(T.(firstName));T.(firstName)=[];
    columnNames=string(T.Properties.VariableNames);
    matrix=double(table2array(T));
    assert(all(isfinite(matrix),'all'), ...
        'plotting:saved_sensitivity_figures:NonfiniteMatrix', ...
        'The saved sensitivity table %s has non-finite values; rerun the step ''sensitivity''.',path);
end

function row=heatmap_figure(values,columnLabels,rowLabels,titleText,name, ...
        cfg,sources,scope)
    fig=figure('Position',[80 80 960 560]);imagesc(values);colorbar;
    [nr,nc]=size(values);xticks(1:nc);xticklabels(columnLabels);xtickangle(24);
    yticks(1:nr);yticklabels(rowLabels);xlabel('input / input pair');
    ylabel('output / derived feature');title(titleText);
    finite=values(isfinite(values));
    if ~isempty(finite)
        limits=[min([finite;0]) max(finite)];
        if limits(1)==limits(2),limits=limits+[-0.5 0.5];end
        clim(limits);
    end
    if numel(values)<=50
        for r=1:nr
            for c=1:nc
                text(c,r,sprintf('%.2f',values(r,c)), ...
                    'HorizontalAlignment','center','FontSize',8);
            end
        end
    end
    row=plotting.export_saved_figure(fig,cfg,'sensitivity',name, ...
        sources,scope,[]);
end

function T=combine(parts)
    if isempty(parts)
        T=empty_manifest();
    else
        T=vertcat(parts{:});
    end
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end
