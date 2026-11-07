function names = certified_only_columns()
%CERTIFIED_ONLY_COLUMNS The design-summary columns that also come for the certified cells alone.
%   NAMES = design_study.certified_only_columns() lists the aggregate and
%   cohort columns of a scenario's design summary (design_summary.csv)
%   that design_study.add_certified_only_summary repeats, with the suffix
%   _certified_only, from the summary over the certified cells alone: the
%   posterior and Fisher-information aggregates over the matched cases, the
%   matched and missing case counts, the matched CaseIDs and the status of
%   the analysis.
%   Side effects: none.
    names = {'MeanQInformation', 'MeanFullInformation', 'MeanDUtility', 'MeanALoss', ...
        'MeanCM3eLoss', 'MeanCK0Loss', 'MeanNormalizedPosteriorSD', 'MeanContractionAmount', ...
        'MeanPosteriorMeanRecoveryErrorU', 'MeanCoverage95', 'MedianConditionNumber', ...
        'MeanNumericalRank', 'MaximumFIMToPosteriorCovarianceRelativeError', ...
        'MaximumJacobianErrorH5e4', 'MaximumJacobianErrorH2e3', 'MatchedCaseCount', ...
        'MissingCaseCount', 'MatchedCaseIDs', 'AnalysisStatus'};
end
