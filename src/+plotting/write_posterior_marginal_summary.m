function pathValue = write_posterior_marginal_summary( ...
        cfg,category,figureName,summary,sources,tableStem,cells)
%WRITE_POSTERIOR_MARGINAL_SUMMARY Save the marginal statistics of a figure's posterior.
%   PATH = plotting.write_posterior_marginal_summary(CFG, CATEGORY,
%   FIGURENAME, SUMMARY, SOURCES, TABLESTEM, CELLS) writes the marginal statistics
%   SUMMARY (rows of plotting.posterior_marginal_summary_row) as
%   <FIGURENAME>_statistics.csv in the tables/ folder next to the figure (for
%   a per-case CATEGORY, 'case/<step>' of study.layout, in the case folder)
%   and returns its path.
%   SOURCES are the saved files the statistics were computed from;
%   reproduce mode checks that each is a saved file (study.export_table).
%   TABLESTEM ('' or, in reproduce mode, a name) names the table
%   <TABLESTEM>_statistics instead: the figures of one posterior cell
%   (marginals, corner plot) pass the cell, <scenario>_<design>, so its
%   statistics are written once rather than once per figure.
%   CELLS are the inversion cells of the posterior (study.index_entry).
%   Side effects: writes the table.
    required={'Series','Parameter','PosteriorMean','PosteriorMedian', ...
        'MarginalMode','Q025','Q25','Q75','Q975','TruthCovered50', ...
        'TruthCovered95','Truth','CentralIntervalConvention', ...
        'DensityEstimationMethod','DensityBinCount', ...
        'DensityBandwidth','DensityBandwidthRule', ...
        'KernelTruncationStandardDeviations','RetainedDrawCount', ...
        'DensityLowerBound','DensityUpperBound','ModeTieBreak'};
    assert(istable(summary)&&~isempty(summary)&& ...
        all(ismember(required,summary.Properties.VariableNames)), ...
        'plotting:write_posterior_marginal_summary:Schema', ...
        'The posterior marginal summary must be a non-empty table with the columns %s.', ...
        strjoin(required,', '));
    if study.is_publication(cfg)
        % Reproduce mode: the publication layout (study.export_table).
        caseID=[];
        if isstruct(cells)&&isfield(cells,'CaseID'),caseID=unique(double([cells.CaseID]));end
        if isempty(tableStem)
            tableStem=char(string(figureName));
            what=['figure ' tableStem];
            if isscalar(caseID),what=sprintf('%s of case %d',what,caseID);end
        else
            tableStem=char(string(tableStem));
            what=strrep(tableStem,'_',' ');
            if isscalar(caseID),what=sprintf('case %d %s',caseID,what);end
        end
        pathValue=study.export_table(cfg,category, ...
            [tableStem '_statistics'],summary(:,required), ...
            sources,['Posterior marginal statistics of ' what],cells);
        return
    end
    outputDirectory=fullfile(cfg.paths.stage07,char(string(category)));
    if ~isfolder(outputDirectory),mkdir(outputDirectory);end
    pathValue=fullfile(outputDirectory, ...
        [char(string(figureName)) '_statistics.csv']);
    utils.atomic_write_table(pathValue,summary(:,required));
end
