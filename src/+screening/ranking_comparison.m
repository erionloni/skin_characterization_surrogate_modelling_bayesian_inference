function [comparisonSummary,rankShift] = ranking_comparison(measurement,operational)
%RANKING_COMPARISON The comparison of the measurement and operational rankings of the protocol screen.
%   [SUMMARY, RANKSHIFT] = screening.ranking_comparison(MEASUREMENT,
%   OPERATIONAL) compares the two rankings of the screen (tables with
%   CandidateID, Rank and IsDefault, MEASUREMENT also CandidateIndex; the
%   rankings of screening.aggregate_rankings, or the shipped
%   measurement_covariance_ranking.csv and operational_ranking.csv). SUMMARY
%   (one row): the Spearman rank correlation over the candidates ranked in
%   both, the Pearson correlation of their ranks matched by CandidateID, in
%   full precision; the default protocol's rank in each and their difference;
%   the overlap of the two top-10 sets; the number compared. RANKSHIFT: the
%   rank of every candidate in both and their difference.
%   Side effects: none.

    % Each ranking is independently score-sorted. Match the CandidateIDs
    % before comparing ranks; positional comparison would always give +1.
    [matched,operationalIndex]=ismember(string(measurement.CandidateID), ...
        string(operational.CandidateID));
    assert(all(matched)&&height(measurement)==height(operational)&& ...
        numel(unique(operationalIndex))==height(measurement), ...
        'screening:aggregate_rankings:RankAlignment', ...
        'Covariance rankings must contain the same unique CandidateIDs.');
    validBoth=isfinite(measurement.Rank)&isfinite(operational.Rank(operationalIndex));
    measurementRank=measurement.Rank(validBoth);
    operationalRank=operational.Rank(operationalIndex(validBoth));
    spearman=utils.pearson_correlation(measurementRank,operationalRank);
    defaultMeasurement=measurement.Rank(measurement.IsDefault);
    defaultOperational=operational.Rank(operational.IsDefault);
    topM=string(measurement.CandidateID(measurement.Rank<=10));
    topO=string(operational.CandidateID(operational.Rank<=10));
    comparisonSummary=table(spearman,defaultMeasurement,defaultOperational, ...
        defaultOperational-defaultMeasurement,numel(intersect(topM,topO)), ...
        nnz(validBoth), ...
        'VariableNames',{'SpearmanRankCorrelation', ...
        'DefaultMeasurementRank','DefaultOperationalRank', ...
        'DefaultOperationalMinusMeasurementRank','Top10OverlapCount', ...
        'ComparedCandidateCount'});
    rankShift=measurement(:,{'CandidateID','CandidateIndex','Rank'});
    rankShift.Properties.VariableNames{'Rank'}='MeasurementRank';
    rankShift=outerjoin(rankShift,operational(:, ...
        {'CandidateID','Rank'}),'Keys','CandidateID','MergeKeys',true, ...
        'Type','full');
    rankShift.Properties.VariableNames{'Rank'}='OperationalRank';
    rankShift.OperationalMinusMeasurementRank= ...
        rankShift.OperationalRank-rankShift.MeasurementRank;
end
