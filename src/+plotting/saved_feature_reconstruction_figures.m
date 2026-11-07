function manifest = saved_feature_reconstruction_figures(cfg,options)
%SAVED_FEATURE_RECONSTRUCTION_FIGURES The figures of the feature reconstruction.
%   MANIFEST = plotting.saved_feature_reconstruction_figures(CFG, OPTIONS)
%   draws, from the saved tables of the feature reconstruction (no GP, no
%   MCMC), per scenario and design the per-feature and per-case errors, the
%   signed errors, truth against reconstruction and the coverage, the D2/D6
%   residuals and the availability, and returns the manifest.
%   Side effects: writes the figures and closes them.
%   Computation: about a minute (over a hundred figures).

    if ~analysis_enabled(cfg)
        manifest=empty_manifest();
        return
    end
    sourceRoot=analysis_root(cfg);
    outputRoot=fullfile(cfg.paths.stage07,'reconstruction','feature_transfer');
    if ~isfolder(outputRoot),mkdir(outputRoot);end
    paths=source_paths(sourceRoot);
    statusParts={};parts={};
    required={paths.registry,paths.matrix,paths.availability,paths.matched};
    missing=required(~cellfun(@isfile,required));
    if ~isempty(missing)
        names=string(cellfun(@file_name,missing,'UniformOutput',false));
        statusParts{end+1}=status_row('required_tables','not_generated', ...
            strjoin(names,'|'),0);
        write_status(outputRoot,statusParts);
        manifest=empty_manifest();
        return
    end

    registry=read_saved_table(paths.registry);
    matrix=read_saved_table(paths.matrix);
    availability=read_saved_table(paths.availability);
    matched=read_saved_table(paths.matched);
    validate_registry(cfg,registry);
    validate_matrix_schema(matrix);
    validate_availability_schema(cfg,availability);
    validate_matched_schema(cfg,matched);
    scenarios=analysis_scenarios();
    designs=canonical_designs(cfg);
    coreSpaces=core_spaces();
    diagnosticSpaces=diagnostic_spaces();
    caseOrder=reshape(double(cfg.inversion.caseIDs),1,[]);
    statusSources=existing_sources( ...
        {paths.availability,paths.matched,paths.status});
    parts{end+1}=availability_figure(cfg,availability,matched,scenarios,designs, ...
        caseOrder,statusSources);
    statusParts{end+1}=status_row('availability','generated','', ...
        height(availability));

    coreMetrics={ ...
        'MeanNormalizedAbsoluteError','mean_normalized_absolute_error', ...
            'Across-case mean normalized absolute error from posterior median'; ...
        'MaximumNormalizedAbsoluteError','maximum_normalized_absolute_error', ...
            'Maximum normalized absolute error from posterior median'; ...
        'Coverage95','latent_coverage_95', ...
            '95% latent truth coverage'};
    for s=1:numel(scenarios)
        for m=1:size(coreMetrics,1)
            values=summary_matrix(matrix,scenarios(s),designs,coreSpaces, ...
                coreMetrics{m,1},'core_active');
            parts{end+1}=matrix_heatmap(cfg,values,designs,coreSpaces, ...
                sprintf('%s: core transfer matrix -- %s', ...
                    display_tag(scenarios(s)),coreMetrics{m,3}), ...
                char(scenarios(s)+'_core_'+string(coreMetrics{m,2})), ...
                existing_sources({paths.matrix,paths.matched}), ...
                'aggregate',strcmp(coreMetrics{m,1},'Coverage95'), ...
                struct('Scenario',scenarios(s))); %#ok<AGROW>
        end
        statusParts{end+1}=status_row(scenarios(s)+'_core_matrices', ...
            'generated','',36); %#ok<AGROW>
    end

    mode=lower(char(string(options.Mode)));
    assert(ismember(mode,{'aggregate','publication','full'}), ...
        'plotting:saved_feature_reconstruction_figures:Mode', ...
        'The figure mode must be aggregate, publication or full, not ''%s''.',mode);
    if ~strcmp(mode,'aggregate')
        for s=1:numel(scenarios)
            values=summary_matrix(matrix,scenarios(s),designs, ...
                diagnosticSpaces,'MeanNormalizedAbsoluteError', ...
                'expanded_diagnostic');
            parts{end+1}=matrix_heatmap(cfg,values,designs, ...
                diagnosticSpaces,sprintf( ...
                '%s: expanded diagnostic-family transfer', ...
                display_tag(scenarios(s))), ...
                char(scenarios(s)+'_expanded_diagnostic_error'), ...
                {paths.matrix},'publication',false,struct('Scenario',scenarios(s))); %#ok<AGROW>
        end
        statusParts{end+1}=status_row('expanded_diagnostic_spaces', ...
            'generated','',36);
        [row,generated,reason]=canonical_pressure_figure(cfg,paths, ...
            registry,caseOrder);
        if generated,parts{end+1}=row;end
        statusParts{end+1}=status_row('canonical_six_panel_pressure', ...
            generated_text(generated),reason,double(generated));
        [row,generated,reason]=surrogate_reference_figure( ...
            cfg,paths,registry);
        if generated,parts{end+1}=row;end
        statusParts{end+1}=status_row('surrogate_only_reference', ...
            generated_text(generated),reason,double(generated));
        [row,generated,reason]=maximum_deviation_figure( ...
            cfg,paths,scenarios,designs);
        if generated,parts{end+1}=row;end
        statusParts{end+1}=status_row('maximum_deviation', ...
            generated_text(generated),reason,double(generated));
        [row,generated,reason]=worst_feature_frequency_figure( ...
            cfg,paths,scenarios,designs,registry);
        if generated,parts{end+1}=row;end
        statusParts{end+1}=status_row('worst_feature_frequency', ...
            generated_text(generated),reason,double(generated));
    end

    if strcmp(mode,'full')
        if isfile(paths.perFeature)
            perFeature=read_saved_table(paths.perFeature);
            validate_per_feature_schema(perFeature);
            allSpaces=[coreSpaces diagnosticSpaces];
            for s=1:numel(scenarios)
                % Per-feature error maps of every evaluation space: the mean
                % normalized error, and the signed native error where all
                % features of the space share one unit.
                for e=1:numel(allSpaces)
                    [row,generated,reason]=per_feature_heatmap(cfg, ...
                        perFeature,registry,scenarios(s),designs, ...
                        allSpaces(e),paths.perFeature);
                    if generated,parts{end+1}=row;end %#ok<AGROW>
                    statusParts{end+1}=status_row( ...
                        scenarios(s)+'_'+allSpaces(e)+ ...
                        '_per_feature',generated_text(generated),reason, ...
                        double(generated)); %#ok<AGROW>
                    [row,generated]=per_feature_signed_heatmap(cfg, ...
                        perFeature,registry,scenarios(s),designs, ...
                        allSpaces(e),paths.perFeature);
                    if generated,parts{end+1}=row;end %#ok<AGROW>
                end
                [row,generated,reason]=probe_residual_figure(cfg, ...
                    perFeature,registry,scenarios(s),designs,paths.perFeature);
                if generated,parts{end+1}=row;end %#ok<AGROW>
                statusParts{end+1}=status_row( ...
                    scenarios(s)+'_d2_d6_residuals', ...
                    generated_text(generated),reason,double(generated)); ...
                    %#ok<AGROW>
            end
        else
            statusParts{end+1}=status_row('full_saved_table_diagnostics', ...
                'not_generated', ...
                'reconstruction_per_feature_summary.csv_missing',0);
        end
        if isfile(paths.long)
            long=read_saved_table(paths.long);validate_long_schema(long);
            for s=1:numel(scenarios)
                for space=["all_six" "physics_guided_full_rank_six" ...
                        "cross_probe_ratios" "cross_probe_differences"]
                    [row,generated]=case_error_heatmap(cfg,long,registry, ...
                        scenarios(s),space,caseOrder,paths.long);
                    if generated,parts{end+1}=row;end %#ok<AGROW>
                end
                [row,generated]=truth_versus_reconstruction(cfg,long,registry, ...
                    scenarios(s),paths.long);
                if generated,parts{end+1}=row;end %#ok<AGROW>
            end
        end
    end
    write_status(outputRoot,statusParts);
    manifest=combine(parts);
end

function paths=source_paths(root)
    paths=struct( ...
        'registry',fullfile(root,'feature_registry.csv'), ...
        'long',fullfile(root,'reconstruction_long_form.csv'), ...
        'perFeature',fullfile(root,'reconstruction_per_feature_summary.csv'), ...
        'matrix',fullfile(root,'reconstruction_matrix_summary.csv'), ...
        'maximum',fullfile(root,'maximum_deviation_summary.csv'), ...
        'worstPerCase',fullfile(root,'worst_feature_per_case.csv'), ...
        'worstFrequency',fullfile(root,'worst_feature_frequency.csv'), ...
        'surrogate',fullfile(root,'surrogate_only_reference.csv'), ...
        'availability',fullfile(root,'availability.csv'), ...
        'matched',fullfile(root,'matched_cohorts.csv'), ...
        'status',fullfile(root,'feature_reconstruction_status.json'));
end

function row=availability_figure(cfg,T,matched,scenarios,designs,cases,sources)
    values=zeros(numel(scenarios)*numel(designs),numel(cases));
    labels=strings(size(values,1),1);cursor=0;
    for s=1:numel(scenarios)
        for d=1:numel(designs)
            cursor=cursor+1;
            labels(cursor)=scenarios(s)+" / "+designs(d);
            for c=1:numel(cases)
                hit=string(T.Scenario)==scenarios(s)& ...
                    string(T.FittingDesign)==designs(d)& ...
                    double(T.CaseID)==cases(c);
                assert(nnz(hit)<=1, ...
                    'plotting:saved_feature_reconstruction_figures:AvailabilityKey', ...
                    ['The saved reconstruction availability table repeats scenario %s, design ' ...
                     '%s and case %d; rerun the step ''recovery''.'],scenarios(s),designs(d),cases(c));
                if nnz(hit)==1
                    matchedHit=string(matched.Scenario)==scenarios(s)& ...
                        double(matched.CaseID)==cases(c);
                    assert(nnz(matchedHit)==1, ...
                        'plotting:saved_feature_reconstruction_figures:MatchedKey', ...
                        ['The saved matched-case table has %d rows for scenario %s and case %d, not ' ...
                         'one; rerun the step ''recovery''.'],nnz(matchedHit),scenarios(s),cases(c));
                    values(cursor,c)=double(to_logical(T.Expected(hit)))+ ...
                        double(to_logical(T.CertifiedPosteriorAvailable(hit)))+ ...
                        double(to_logical(T.ReconstructionValid(hit)))+ ...
                        double(to_logical( ...
                        matched.IncludedInMatchedCohort(matchedHit)));
                end
            end
        end
    end
    fig=figure('Position',[35 70 1320 600]);imagesc(values,[0 4]);
    colormap(fig,[0.78 0.78 0.78;0.94 0.72 0.29;0.42 0.68 0.83; ...
        0.24 0.62 0.50;0.08 0.45 0.25]);
    bar=colorbar;bar.Ticks=0:4;bar.TickLabels={ ...
        'not expected','expected','posterior','reconstructed','matched'};
    xticks(1:numel(cases));xticklabels(string(cases));xtickangle(35);
    yticks(1:numel(labels));yticklabels(labels);
    xlabel('CaseID (canonical order)');
    title('Feature-space reconstruction availability and matched cohort');
    row=plotting.export_saved_figure(fig,cfg, ...
        'reconstruction/feature_transfer','reconstruction_availability', ...
        sources,'aggregate',struct('Scenario',analysis_scenarios()));
end

function row=matrix_heatmap(cfg,values,rowLabels,columnLabels,titleText, ...
        name,sources,scope,isCoverage,cells)
    fig=figure('Position',[45 75 1120 640]);
    displayValues=values;finite=isfinite(values);
    displayValues(~finite)=0;
    if isCoverage
        imageHandle=imagesc(displayValues,[0 1]);
    else
        upper=max(displayValues(finite),[],'omitnan');
        if isempty(upper)||~isfinite(upper)||upper<=0,upper=1;end
        imageHandle=imagesc(displayValues,[0 upper]);
    end
    imageHandle.AlphaData=double(finite);set(gca,'Color',[0.82 0.82 0.82]);
    colorbar;xticks(1:numel(columnLabels));xticklabels(columnLabels);
    xtickangle(25);yticks(1:numel(rowLabels));yticklabels(rowLabels);
    xlabel('Evaluation space');ylabel('Posterior fitting design');
    title(titleText,'Interpreter','none');
    for r=1:size(values,1)
        for c=1:size(values,2)
            if isfinite(values(r,c))
                text(c,r,sprintf('%.3f',values(r,c)), ...
                    'HorizontalAlignment','center','FontWeight','bold');
            else
                text(c,r,'NA','HorizontalAlignment','center', ...
                    'Color',[0.35 0.35 0.35]);
            end
        end
    end
    row=plotting.export_saved_figure(fig,cfg, ...
        'reconstruction/feature_transfer',name,sources,scope,cells);
end

function values=summary_matrix(T,scenario,designs,spaces,metric,className)
    values=nan(numel(designs),numel(spaces));
    assert(ismember(metric,T.Properties.VariableNames), ...
        'plotting:saved_feature_reconstruction_figures:MatrixMetric', ...
        ['The saved reconstruction summary lacks the metric column %s; rerun the ' ...
         'step ''recovery''.'],metric);
    for d=1:numel(designs)
        for e=1:numel(spaces)
            hit=string(T.Scenario)==scenario& ...
                string(T.FittingDesign)==designs(d)& ...
                string(T.EvaluationSpace)==spaces(e)& ...
                string(T.EvaluationClass)==className&is_matched(T.CohortType);
            assert(nnz(hit)<=1, ...
                'plotting:saved_feature_reconstruction_figures:MatrixKey', ...
                'Matrix-summary keys must be unique.');
            if nnz(hit)==1,values(d,e)=double(T.(metric)(hit));end
        end
    end
end

function [row,generated,reason]=canonical_pressure_figure( ...
        cfg,paths,registry,cases)
    row=empty_manifest();generated=false;reason="";
    if ~isfile(paths.long)
        reason="reconstruction_long_form.csv_missing";return
    end
    T=read_saved_table(paths.long);validate_long_schema(T);
    rows=string(T.Scenario)=="measurement_plus_gp"& ...
        string(T.FittingDesign)=="all_six"& ...
        string(T.EvaluationSpace)=="all_six";
    one=T(rows,:);
    features=registry_features(registry,"all_six");
    if isempty(one)||height(features)~=6
        reason="canonical_pressure_rows_unavailable";return
    end
    fig=figure('Position',[20 35 1390 790]);
    tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
    for f=1:6
        nexttile;hold on;
        truth=nan(numel(cases),1);medianValue=truth;q025=truth;q975=truth;
        featureID=string(features.FeatureID(f));
        for c=1:numel(cases)
            hit=double(one.CaseID)==cases(c)& ...
                string(one.FeatureID)==featureID;
            assert(nnz(hit)<=1, ...
                'plotting:saved_feature_reconstruction_figures:CanonicalKey', ...
                ['The saved reconstruction table repeats case %d and feature %s; rerun the ' ...
                 'step ''recovery''.'],cases(c),featureID);
            if nnz(hit)==1
                truth(c)=double(one.Truth(hit));
                medianValue(c)=double(one.PosteriorMedian(hit));
                q025(c)=double(one.Q025(hit));q975(c)=double(one.Q975(hit));
            end
        end
        x=(1:numel(cases)).';valid=isfinite(medianValue)& ...
            isfinite(q025)&isfinite(q975);
        if any(valid)
            errorbar(x(valid),medianValue(valid), ...
                medianValue(valid)-q025(valid),q975(valid)-medianValue(valid), ...
                'o','Color',[0.12 0.43 0.70],'MarkerFaceColor', ...
                [0.12 0.43 0.70],'LineWidth',1.0,'CapSize',3);
        end
        truthValid=isfinite(truth);
        plot(x(truthValid),truth(truthValid),'kx','LineWidth',1.4, ...
            'MarkerSize',6);
        grid on;xticks(1:numel(cases));xticklabels(string(cases));
        xtickangle(45);ylabel(char(string(features.Units(f))));
        title(char(string(features.ScalarFeature(f))),'Interpreter','none');
        if f==1
            legend({'posterior median + 95% latent interval','COMSOL truth'}, ...
                'Location','best');
        end
    end
    sgtitle(['all_six / measurement_plus_gp: latent closing-pressure ' ...
        'reconstruction (canonical cases)'],'Interpreter','none');
    row=plotting.export_saved_figure(fig,cfg, ...
        'reconstruction/feature_transfer', ...
        'measurement_plus_gp_all_six_closing_pressure_reconstruction', ...
        existing_sources({paths.long,paths.registry,paths.matched}), ...
        'publication',struct('Scenario','measurement_plus_gp','Design','all_six'));
    generated=true;
end

function [row,generated,reason]=surrogate_reference_figure(cfg,paths,registry)
    row=empty_manifest();generated=false;reason="";
    if ~isfile(paths.surrogate)
        reason="surrogate_only_reference.csv_missing";return
    end
    T=read_saved_table(paths.surrogate);
    required=["CaseID" "EvaluationSpace" "FeatureID" ...
        "NormalizedAbsoluteError" "NormalizedMetricAvailable"];
    require_columns(T,required,'SurrogateSchema');
    spaces=[core_spaces() diagnostic_spaces()];
    means=nan(numel(spaces),1);maxima=means;
    for e=1:numel(spaces)
        one=T(string(T.EvaluationSpace)==spaces(e)& ...
            to_logical(T.NormalizedMetricAvailable),:);
        features=registry_features(registry,spaces(e));
        featureMeans=nan(height(features),1);featureMax=featureMeans;
        for f=1:height(features)
            hit=string(one.FeatureID)==string(features.FeatureID(f));
            values=double(one.NormalizedAbsoluteError(hit));
            values=values(isfinite(values));
            if ~isempty(values)
                featureMeans(f)=mean(values);featureMax(f)=max(values);
            end
        end
        means(e)=mean(featureMeans,'omitnan');
        maxima(e)=max(featureMax,[],'omitnan');
    end
    if ~any(isfinite(means))
        reason="no_normalized_surrogate_reference_values";return
    end
    fig=figure('Position',[45 75 1120 620]);
    tiledlayout(2,1,'Padding','compact','TileSpacing','compact');
    nexttile;bar(means);ylabel('Mean normalized absolute error');grid on;
    title('Surrogate-only reference (equal feature weight)');
    nexttile;bar(maxima);ylabel('Maximum normalized absolute error');grid on;
    xticks(1:numel(spaces));xticklabels(spaces);xtickangle(25);
    xlabel('Evaluation space');
    row=plotting.export_saved_figure(fig,cfg, ...
        'reconstruction/feature_transfer', ...
        'surrogate_only_feature_space_reference', ...
        {paths.surrogate,paths.registry},'publication',[]);
    generated=true;
end

function [row,generated,reason]=maximum_deviation_figure( ...
        cfg,paths,scenarios,designs)
    row=empty_manifest();generated=false;reason="";
    if ~isfile(paths.maximum)
        reason="maximum_deviation_summary.csv_missing";return
    end
    T=read_saved_table(paths.maximum);
    required=["Scenario" "FittingDesign" "EvaluationSpace" ...
        "CohortType" "MaximumNormalizedAbsoluteError" "CaseID" ...
        "ScalarFeature" "FeatureID"];
    require_columns(T,required,'MaximumSchema');
    fig=figure('Position',[45 75 1220 660]);
    tiledlayout(2,1,'Padding','compact','TileSpacing','compact');
    anyValue=false;
    for s=1:numel(scenarios)
        nexttile;values=nan(numel(designs),1);labels=strings(numel(designs),1);
        for d=1:numel(designs)
            hit=string(T.Scenario)==scenarios(s)& ...
                string(T.FittingDesign)==designs(d)&is_matched(T.CohortType);
            one=T(hit,:);candidate=double(one.MaximumNormalizedAbsoluteError);
            candidate(~isfinite(candidate))=-inf;
            [value,index]=max(candidate);
            if ~isempty(index)&&isfinite(value)
                values(d)=value;labels(d)=sprintf('Case %d / %s', ...
                    double(one.CaseID(index)), ...
                    char(string(one.ScalarFeature(index))));
                anyValue=true;
            end
        end
        bar(values);grid on;
        ylabel('Maximum normalized absolute error from posterior median');
        xticks(1:numel(designs));xticklabels(designs);xtickangle(24);
        title(display_tag(scenarios(s)),'Interpreter','none');
        for d=1:numel(designs)
            if isfinite(values(d))
                text(d,values(d),labels(d),'Rotation',25, ...
                    'VerticalAlignment','bottom','HorizontalAlignment','left', ...
                    'FontSize',7,'Interpreter','none');
            end
        end
    end
    sgtitle('Worst saved feature deviation by posterior fitting design');
    if ~anyValue
        close(fig);reason="no_finite_maximum_deviation_values";return
    end
    row=plotting.export_saved_figure(fig,cfg, ...
        'reconstruction/feature_transfer', ...
        'maximum_feature_deviation_provenance',{paths.maximum},'publication',struct('Scenario',analysis_scenarios()));
    generated=true;
end

function [row,generated,reason]=worst_feature_frequency_figure( ...
        cfg,paths,scenarios,designs,registry)
    row=empty_manifest();generated=false;reason="";
    if ~isfile(paths.worstFrequency)
        reason="worst_feature_frequency.csv_missing";return
    end
    T=read_saved_table(paths.worstFrequency);
    required=["Scenario" "FittingDesign" "EvaluationSpace" ...
        "CohortType" "FeatureID" "FeatureFamily" "FeatureIndex" ...
        "WorstFeatureCount" "IncludedCaseCount" "WorstFeatureFraction" ...
        "TiedCaseCount" "TieBreakPolicy"];
    require_columns(T,required,'WorstFeatureFrequencySchema');
    T=T(is_matched(T.CohortType),:);
    rawFeatures=registry_features(registry,"all_six");
    rawValues=nan(numel(scenarios)*numel(designs),height(rawFeatures));
    rawLabels=strings(size(rawValues,1),1);cursor=0;
    for s=1:numel(scenarios)
        for d=1:numel(designs)
            cursor=cursor+1;rawLabels(cursor)=scenarios(s)+" / "+designs(d);
            for f=1:height(rawFeatures)
                hit=T.Scenario==scenarios(s)&T.FittingDesign==designs(d)& ...
                    T.EvaluationSpace=="all_six"& ...
                    T.FeatureID==rawFeatures.FeatureID(f);
                assert(nnz(hit)<=1, ...
                    'plotting:saved_feature_reconstruction_figures:WorstRawKey', ...
                    ['The saved reconstruction table repeats scenario %s, design %s and ' ...
                     'feature %s; rerun the step ''recovery''.'],scenarios(s),designs(d), ...
                    string(rawFeatures.FeatureID(f)));
                if nnz(hit)==1
                    rawValues(cursor,f)=double(T.WorstFeatureFraction(hit));
                end
            end
        end
    end

    spaces=[core_spaces() diagnostic_spaces()];
    families=["raw_pressure" "within_probe_ratio" "within_probe_drop" ...
        "cross_probe_ratio" "cross_probe_difference"];
    familyValues=nan(numel(scenarios)*numel(spaces),numel(families));
    familyLabels=strings(size(familyValues,1),1);cursor=0;
    for s=1:numel(scenarios)
        for e=1:numel(spaces)
            cursor=cursor+1;familyLabels(cursor)=scenarios(s)+" / "+spaces(e);
            one=T(T.Scenario==scenarios(s)&T.EvaluationSpace==spaces(e),:);
            total=sum(double(one.WorstFeatureCount));
            if total>0
                for f=1:numel(families)
                    familyValues(cursor,f)=sum(double(one.WorstFeatureCount( ...
                        one.FeatureFamily==families(f))))/total;
                end
            end
        end
    end
    if ~any(isfinite(rawValues),'all')&&~any(isfinite(familyValues),'all')
        reason="no_available_matched_worst_feature_frequencies";return
    end
    fig=figure('Position',[35 45 1320 900]);
    tiledlayout(2,1,'Padding','compact','TileSpacing','compact');
    nexttile;imagesc(rawValues,[0 1]);colorbar;
    xticks(1:height(rawFeatures));xticklabels(rawFeatures.FeatureID);
    yticks(1:numel(rawLabels));yticklabels(rawLabels);
    title('Per-case worst raw-output frequency');
    nexttile;imagesc(familyValues,[0 1]);colorbar;
    xticks(1:numel(families));xticklabels(families);xtickangle(22);
    yticks(1:numel(familyLabels));yticklabels(familyLabels);
    title('Per-case worst-feature family frequency');
    sgtitle(['Worst-feature frequencies from normalized absolute error ' ...
        'at the posterior median; exact ties use the lowest canonical index']);
    row=plotting.export_saved_figure(fig,cfg, ...
        'reconstruction/feature_transfer','worst_feature_frequency', ...
        {paths.worstFrequency,paths.worstPerCase},'publication',struct('Scenario',analysis_scenarios()));
    generated=true;
end

function [row,generated,reason]=per_feature_heatmap( ...
        cfg,T,registry,scenario,designs,space,source)
    row=empty_manifest();generated=false;reason="";
    features=registry_features(registry,space);
    one=T(string(T.Scenario)==scenario& ...
        string(T.EvaluationSpace)==space&is_matched(T.CohortType),:);
    if isempty(one)||isempty(features)
        reason="no_matched_per_feature_rows";return
    end
    values=nan(numel(designs),height(features));
    for d=1:numel(designs)
        for f=1:height(features)
            hit=string(one.FittingDesign)==designs(d)& ...
                string(one.FeatureID)==string(features.FeatureID(f));
            assert(nnz(hit)<=1, ...
                'plotting:saved_feature_reconstruction_figures:PerFeatureKey', ...
                ['The saved reconstruction table repeats design %s and feature %s; rerun ' ...
                 'the step ''recovery''.'],designs(d),string(features.FeatureID(f)));
            if nnz(hit)==1&&to_logical(one.NormalizedMetricAvailable(hit))
                values(d,f)=double(one.MeanNormalizedAbsoluteError(hit));
            end
        end
    end
    if ~any(isfinite(values),'all')
        reason="no_finite_per_feature_values";return
    end
    fig=feature_heatmap(values,designs,string(features.ScalarFeature), ...
        'posterior fitting design',sprintf('%s: per-feature error, %s features', ...
        plotting.display_name('scenario',scenario),strrep(char(space),'_',' ')), ...
        'mean |error of the posterior-median reconstruction| / feature range',false);
    row=plotting.export_saved_figure(fig,cfg,'reconstruction/feature_transfer', ...
        char(scenario+'_'+space+'_error'),{source},'diagnostic', ...
        cells_of(cfg,scenario,space));
    generated=true;
end

function [row,generated]=per_feature_signed_heatmap( ...
        cfg,T,registry,scenario,designs,space,source)
%PER_FEATURE_SIGNED_HEATMAP Mean signed error per design and feature, native units.
%   Only for evaluation spaces whose features share one unit. The quantity
%   is the across-case mean of the signed error of the posterior-MEAN
%   reconstruction (MeanSignedNativeError), on the matched case cohort.
    row=empty_manifest();generated=false;
    features=registry_features(registry,space);
    units=unique(string(features.Units));
    one=T(string(T.Scenario)==scenario& ...
        string(T.EvaluationSpace)==space&is_matched(T.CohortType),:);
    if isempty(one)||isempty(features)||numel(units)~=1,return;end
    values=nan(numel(designs),height(features));
    for d=1:numel(designs)
        for f=1:height(features)
            hit=string(one.FittingDesign)==designs(d)& ...
                string(one.FeatureID)==string(features.FeatureID(f));
            if nnz(hit)==1,values(d,f)=double(one.MeanSignedNativeError(hit));end
        end
    end
    if ~any(isfinite(values),'all'),return;end
    fig=feature_heatmap(values,designs,string(features.ScalarFeature), ...
        'posterior fitting design',sprintf('%s: per-feature signed error, %s features', ...
        plotting.display_name('scenario',scenario),strrep(char(space),'_',' ')), ...
        sprintf('mean signed error of the posterior-mean reconstruction [%s]',units),true);
    row=plotting.export_saved_figure(fig,cfg,'reconstruction/feature_transfer', ...
        char(scenario+'_'+space+'_signed_error'),{source},'diagnostic', ...
        cells_of(cfg,scenario,space));
    generated=true;
end

function [row,generated]=case_error_heatmap(cfg,T,registry,scenario,space,cases,source)
%CASE_ERROR_HEATMAP Per-case feature errors of the all_six posterior.
%   Signed error of the posterior-median reconstruction in native units; for
%   the physics-guided space, whose features have different units, the
%   absolute error normalized by the feature range instead.
    row=empty_manifest();generated=false;
    features=registry_features(registry,space);
    one=T(string(T.Scenario)==scenario&string(T.FittingDesign)=="all_six"& ...
        string(T.EvaluationSpace)==space&to_logical(T.ReconstructionValid),:);
    if isempty(one)||isempty(features),return;end
    if space=="physics_guided_full_rank_six"
        metric='NormalizedAbsoluteErrorFromPosteriorMedian';signed=false;
        label='|error of the posterior-median reconstruction| / feature range';
    else
        metric='SignedErrorFromPosteriorMedian';signed=true;
        label=sprintf('signed error of the posterior-median reconstruction [%s]', ...
            strjoin(unique(string(features.Units)),', '));
    end
    values=nan(numel(cases),height(features));
    for c=1:numel(cases)
        for f=1:height(features)
            hit=double(one.CaseID)==cases(c)& ...
                string(one.FeatureID)==string(features.FeatureID(f));
            if nnz(hit)==1,values(c,f)=double(one.(metric)(hit));end
        end
    end
    fig=feature_heatmap(values,string(cases),string(features.ScalarFeature),'CaseID', ...
        sprintf('%s, all six outputs: reconstructed %s features per case', ...
        plotting.display_name('scenario',scenario),strrep(char(space),'_',' ')),label,signed);
    row=plotting.export_saved_figure(fig,cfg,'reconstruction/feature_transfer', ...
        char(scenario+'_'+space+'_case_errors'),{source},'diagnostic', ...
        cells_of(cfg,scenario,space));
    generated=true;
end

function [row,generated]=truth_versus_reconstruction(cfg,T,registry,scenario,source)
%TRUTH_VERSUS_RECONSTRUCTION COMSOL pressure against its posterior reconstruction.
    row=empty_manifest();generated=false;
    features=registry_features(registry,"all_six");
    one=T(string(T.Scenario)==scenario&string(T.FittingDesign)=="all_six"& ...
        string(T.EvaluationSpace)=="all_six"&to_logical(T.ReconstructionValid),:);
    if isempty(one)||height(features)~=6,return;end
    fig=figure('Position',[40 40 1350 780]);
    layout=tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');
    for f=1:6
        nexttile(layout);hold on;
        q=one(string(one.FeatureID)==string(features.FeatureID(f)),:);
        truth=double(q.Truth);medianValue=double(q.PosteriorMedian);
        for i=1:height(q)
            plot([truth(i) truth(i)],[double(q.Q025(i)) double(q.Q975(i))],'-', ...
                'Color',[0.14 0.48 0.63 0.35],'LineWidth',1.2);
        end
        scatter(truth,medianValue,24,[0.14 0.48 0.63],'filled');
        limits=[min([truth;double(q.Q025)]) max([truth;double(q.Q975)])];
        plot(limits,limits,'k--');
        name=string(features.ScalarFeature(f));
        title(plotting.display_name('output',name),'Interpreter','tex');
        xlabel('COMSOL pressure [mbar]');ylabel('reconstructed pressure [mbar]');
    end
    title(layout,sprintf(['%s, all six outputs: six-pressure reconstruction ' ...
        '(posterior median and 95%% interval)'],plotting.display_name('scenario',scenario)));
    row=plotting.export_saved_figure(fig,cfg,'reconstruction/feature_transfer', ...
        char(scenario+'_truth_vs_reconstruction'),{source},'diagnostic', ...
        struct('Scenario',scenario));
    generated=true;
end

function fig=feature_heatmap(values,rowLabels,columnLabels,rowTitle,titleText, ...
        colorLabel,signed)
%FEATURE_HEATMAP Heatmap with a value in every cell; missing cells grey, not zero.
    fig=figure('Position',[45 75 max(900,90*numel(columnLabels)+300) ...
        max(420,28*numel(rowLabels)+200)]);
    finite=isfinite(values);display=values;display(~finite)=0;
    if signed
        limit=max(abs(values(finite)));if isempty(limit)||limit==0,limit=1;end
        handle=imagesc(display,[-limit limit]);colormap(fig,blue_white_red());
    else
        upper=max(values(finite));if isempty(upper)||upper<=0,upper=1;end
        handle=imagesc(display,[0 upper]);colormap(fig,parula);
    end
    handle.AlphaData=double(finite);set(gca,'Color',[0.82 0.82 0.82]);
    cb=colorbar;cb.Label.String=colorLabel;
    xticks(1:numel(columnLabels));xticklabels(columnLabels);xtickangle(25);
    yticks(1:numel(rowLabels));yticklabels(rowLabels);
    set(gca,'TickLabelInterpreter','none');
    xlabel('feature');ylabel(rowTitle);
    if numel(values)<=160
        for r=1:size(values,1)
            for c=1:size(values,2)
                if finite(r,c)
                    text(c,r,sprintf('%.2g',values(r,c)),'HorizontalAlignment','center', ...
                        'FontSize',8);
                end
            end
        end
    end
    grid off;
    title(titleText,'Interpreter','none');
end


function [row,generated,reason]=probe_residual_figure( ...
        cfg,T,registry,scenario,designs,source)
    row=empty_manifest();generated=false;reason="";
    features=registry_features(registry,"all_six");
    one=T(string(T.Scenario)==scenario& ...
        string(T.EvaluationSpace)=="all_six"&is_matched(T.CohortType),:);
    if isempty(one)||height(features)~=6
        reason="raw_pressure_residual_rows_unavailable";return
    end
    values=nan(numel(designs),6);
    for d=1:numel(designs)
        for f=1:6
            hit=string(one.FittingDesign)==designs(d)& ...
                string(one.FeatureID)==string(features.FeatureID(f));
            assert(nnz(hit)<=1, ...
                'plotting:saved_feature_reconstruction_figures:ResidualKey', ...
                ['The saved reconstruction residual table repeats design %s and feature %s; ' ...
                 'rerun the step ''recovery''.'],designs(d),string(features.FeatureID(f)));
            if nnz(hit)==1
                values(d,f)=double(one.MeanSignedNativeError(hit));
            end
        end
    end
    if ~any(isfinite(values),'all')
        reason="no_finite_raw_pressure_residuals";return
    end
    limit=max(abs(values),[],'all','omitnan');
    if ~isfinite(limit)||limit==0,limit=1;end
    fig=figure('Position',[45 75 1250 570]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    for probe=1:2
        nexttile;columns=(1:3)+(probe-1)*3;
        imagesc(values(:,columns),[-limit limit]);
        xticks(1:3);xticklabels(string(features.ScalarFeature(columns)));
        xtickangle(20);yticks(1:numel(designs));yticklabels(designs);
        xlabel('Raw pressure output');ylabel('Posterior fitting design');
        % CLN-055: MeanSignedNativeError is the across-case mean of the
        % signed error of the posterior-mean reconstruction, not of the median.
        title(sprintf('D%d mean signed error of the posterior mean',2+4*(probe-1)));
        colorbar;
    end
    colormap(fig,blue_white_red());
    sgtitle(sprintf('%s: saved D2/D6 raw-pressure residuals', ...
        display_tag(scenario)),'Interpreter','none');
    row=plotting.export_saved_figure(fig,cfg, ...
        'reconstruction/feature_transfer', ...
        char(scenario+'_d2_d6_signed_residuals'),{source},'diagnostic', ...
        struct('Scenario',scenario));
    generated=true;
end

function validate_registry(cfg,T)
    required=["EvaluationSpaceOrder" "EvaluationSpace" ...
        "EvaluationSpaceLabel" "EvaluationClass" "FeatureIndex" ...
        "ScalarFeature" "FeatureID" "FeatureFamily" "Units" "Formula" ...
        "Nonlinear" "DenominatorPolicy"];
    require_columns(T,required,'RegistrySchema');
    expected=[core_spaces() diagnostic_spaces()];
    observed=unique(string(T.EvaluationSpace),'stable').';
    assert(isequal(observed,expected), ...
        'plotting:saved_feature_reconstruction_figures:RegistryOrder', ...
        'The saved feature registry does not use the canonical 6+3 order.');
    assert(isequal(canonical_designs(cfg),core_spaces()), ...
        'plotting:saved_feature_reconstruction_figures:DesignOrder', ...
        'The study''s designs are not the six canonical designs of the feature reconstruction.');
    keys=string(T.EvaluationSpace)+"|"+string(T.FeatureID);
    assert(numel(unique(keys))==height(T), ...
        'plotting:saved_feature_reconstruction_figures:RegistryKeys', ...
        ['The saved feature registry repeats evaluation-space and feature rows; ' ...
         'rerun the step ''recovery''.']);
end

function validate_matrix_schema(T)
    required=["Scenario" "FittingDesign" "EvaluationSpace" ...
        "EvaluationClass" "CohortType" "MeanNormalizedAbsoluteError" ...
        "MedianNormalizedAbsoluteError" "NormalizedRMSE" ...
        "MaximumNormalizedAbsoluteError" "MeanSignedNativeError" ...
        "MeanNativeAbsoluteError" "NativeRMSE" "MedianIntervalWidth" ...
        "Coverage95" "IncludedCaseCount" "NumberScalarFeatures" ...
        "ExcludedCaseIDs" "ExclusionReasons" ...
        "EqualScalarFeatureWeighting"];
    require_columns(T,required,'MatrixSchema');
end

function validate_availability_schema(cfg,T)
    required=["Scenario" "CaseID" "FittingDesign" "Expected" ...
        "CertifiedPosteriorAvailable" "ReconstructionValid" ...
        "ExclusionReason"];
    require_columns(T,required,'AvailabilitySchema');
    keys=string(T.Scenario)+"|"+string(T.CaseID)+"|"+ ...
        string(T.FittingDesign);
    assert(height(T)==2*numel(cfg.inversion.caseIDs)*6&& ...
        numel(unique(keys))==height(T), ...
        'plotting:saved_feature_reconstruction_figures:AvailabilityKeys', ...
        ['The saved reconstruction availability table needs one row per scenario, ' ...
         'case and design (%d); it has %d rows, %d distinct; rerun the step ' ...
         '''recovery''.'],2*numel(cfg.inversion.caseIDs)*6,height(T),numel(unique(keys)));
end

function validate_matched_schema(cfg,T)
    required=["Scenario" "CaseID" "Expected" ...
        "IncludedInMatchedCohort" "ExclusionReason"];
    require_columns(T,required,'MatchedSchema');
    keys=string(T.Scenario)+"|"+string(T.CaseID);
    assert(height(T)==2*numel(cfg.inversion.caseIDs)&& ...
        numel(unique(keys))==height(T), ...
        'plotting:saved_feature_reconstruction_figures:MatchedKeys', ...
        ['The saved matched-case table needs one row per scenario and case (%d); it ' ...
         'has %d rows, %d distinct; rerun the step ''recovery''.'], ...
        2*numel(cfg.inversion.caseIDs),height(T),numel(unique(keys)));
end

function validate_long_schema(T)
    required=["Scenario" "CaseID" "FittingDesign" "EvaluationSpace" ...
        "FeatureID" "FeatureFamily" "FeatureIndex" "Units" "Truth" ...
        "PosteriorMedian" "Q025" "Q975" "SignedMedianError" ...
        "NormalizedAbsoluteError" "NormalizedMetricAvailable" ...
        "Covered95" "IncludedInMatchedCohort" ...
        "ExecutionStatus" "FailureReason"];
    require_columns(T,required,'LongSchema');
end

function validate_per_feature_schema(T)
    required=["Scenario" "FittingDesign" "EvaluationSpace" ...
        "EvaluationClass" "FeatureID" "ScalarFeature" "FeatureFamily" ...
        "FeatureIndex" "Units" "CohortType" ...
        "NormalizedMetricAvailable" "MeanNormalizedAbsoluteError" ...
        "MeanSignedNativeError"];
    require_columns(T,required,'PerFeatureSchema');
end

function require_columns(T,required,suffix)
    assert(all(ismember(required,string(T.Properties.VariableNames))), ...
        ['plotting:saved_feature_reconstruction_figures:' suffix], ...
        'A saved reconstruction table of the recovery does not satisfy its schema.');
end

function T=registry_features(registry,space)
    T=registry(string(registry.EvaluationSpace)==space,:);
    [~,order]=sort(double(T.FeatureIndex));T=T(order,:);
end

function designs=canonical_designs(cfg)
    designs=reshape(string(cfg.inversion.designNames),1,[]);
    assert(isequal(designs,core_spaces()), ...
        'plotting:saved_feature_reconstruction_figures:CanonicalDesigns', ...
        'The configured inversion designs are not the six canonical designs in their order.');
end

function spaces=core_spaces()
    spaces=["all_six" "d2_only" "d6_only" "cycle_1_only" ...
        "ratios_only" "physics_guided_full_rank_six"];
end

function spaces=diagnostic_spaces()
    spaces=["within_probe_drops" "cross_probe_ratios" ...
        "cross_probe_differences"];
end

function cells=cells_of(cfg,scenario,space)
%CELLS_OF The inversion cells behind a figure of one scenario and one design or feature space.
%   A figure of one observation design shows that design's cells; a figure
%   of a feature space shows every design of the scenario.
    cells=struct('Scenario',scenario);
    if ismember(string(space),string(cfg.inversion.designNames))
        cells.Design=space;
    end
end

function scenarios=analysis_scenarios()
    scenarios=["measurement_plus_gp" "gp_only"];
end

function root=analysis_root(cfg)
    root=study.source_folder(cfg,'feature_reconstruction');
end

function tf=analysis_enabled(cfg)
%ANALYSIS_ENABLED The feature-reconstruction setting (A.7).
    tf=logical(cfg.analysis.runFeatureReconstructionAnalysis);
end

function T=read_saved_table(path)
    T=readtable(path,'Delimiter',',','TextType','string','VariableNamingRule','preserve');
end

function sources=existing_sources(paths)
    sources=paths(cellfun(@isfile,paths));
end

function textValue=display_tag(value)
    textValue=strrep(char(string(value)),'_',' ');
end

function name=file_name(path)
    [~,stem,ext]=fileparts(path);name=[stem ext];
end

function value=to_logical(input)
    if islogical(input),value=input;return;end
    if isnumeric(input),value=input~=0;return;end
    value=ismember(lower(string(input)),["true" "1"]);
end

function value=is_matched(input)
    value=contains(lower(string(input)),"matched");
end

function textValue=generated_text(generated)
    if generated,textValue="generated";else,textValue="not_generated";end
end

function T=status_row(item,status,reason,count)
    T=table(string(item),string(status),string(reason),double(count), ...
        'VariableNames',{'Item','Status','Reason','Count'});
end

function write_status(root,parts)
    if isempty(parts)
        T=table('Size',[0 4],'VariableTypes', ...
            {'string','string','string','double'}, ...
            'VariableNames',{'Item','Status','Reason','Count'});
    else
        T=vertcat(parts{:});
    end
    utils.atomic_write_table(fullfile(root, ...
        'feature_reconstruction_figure_status.csv'),T);
end

function map=blue_white_red()
    n=256;half=n/2;
    left=[linspace(0.10,1,half).' linspace(0.25,1,half).' ones(half,1)];
    right=[ones(half,1) linspace(1,0.20,half).' ...
        linspace(1,0.12,half).'];
    map=[left;right];
end

function T=combine(parts)
    if isempty(parts),T=empty_manifest();else,T=vertcat(parts{:});end
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end
