function result = sequential_information(provider,caseIndex,sequenceName)
%SEQUENTIAL_INFORMATION How the posterior information grows from an output subset to all six outputs.
%   RESULT = design_study.sequential_information(PROVIDER, CASEINDEX,
%   SEQUENCENAME) compares, for the case CASEINDEX, the posterior metrics
%   (design_study.posterior_metrics) of two registered designs: d2_to_all_six
%   (default: D2 only, then all six), d6_to_all_six or cycle1_to_all_six.
%   RESULT: per step the full and target information gain, the traces, the
%   mean recovery error, the coverage and the mean normalized width.
%   Side effects: none.
    if nargin < 3 || isempty(sequenceName), sequenceName = 'd2_to_all_six'; end
    sequenceName = char(lower(string(sequenceName)));
    switch sequenceName
        case 'd2_to_all_six'
            sequenceName='d2_to_all_six';
            % Use only the registered two-point output-subset comparison;
            % no ninth posterior cell is added.
            designNames = {'d2_only','all_six'};
            labels = {'D2 only','All D2 and D6'};
        case 'd6_to_all_six'
            sequenceName='d6_to_all_six';
            designNames={'d6_only','all_six'};
            labels={'D6 only','All D2 and D6'};
        case 'cycle1_to_all_six'
            sequenceName='cycle1_to_all_six';
            designNames={'cycle_1_only','all_six'};
            labels={'Cycle 1 only','All three cycles'};
        otherwise
            error('design_study:sequential_information:UnknownSequence', ...
                ['Sequence must be d2_to_all_six, d6_to_all_six, or ' ...
                 'cycle1_to_all_six.']);
    end
    n = numel(designNames);
    registeredNames={provider.designs.name};
    assert(all(ismember(designNames,registeredNames)), ...
        'design_study:sequential_information:UnregisteredDesign', ...
        'Every sequential-information step must use a registered design.');
    fullInformation = zeros(n,1);
    qInformation = zeros(n,1);
    fullTrace = zeros(n,1);
    qTrace = zeros(n,1);
    meanRecovery = zeros(n,1);
    coverage = zeros(n,1);
    meanNormalizedWidth = zeros(n,1);
    covariance = cell(n,1);
    for i = 1:n
        metrics = design_study.posterior_metrics(provider,caseIndex,designNames{i});
        fullInformation(i) = metrics.full_information_gain;
        qInformation(i) = metrics.q_information_gain;
        fullTrace(i) = metrics.full_trace;
        qTrace(i) = metrics.q_trace;
        meanRecovery(i) = mean(metrics.posterior_mean_recovery_error_u);
        coverage(i) = mean(metrics.truth_covered_95);
        meanNormalizedWidth(i) = mean(metrics.normalized_posterior_sd);
        covariance{i} = metrics.posterior_covariance_u;
    end
    fullIncrement = [fullInformation(1);diff(fullInformation)];
    qIncrement = [qInformation(1);diff(qInformation)];
    tolerance = 1e-10;
    minimumPSD = nan(n,1);
    for i = 2:n
        minimumPSD(i) = min(eig((covariance{i-1}-covariance{i}+ ...
            (covariance{i-1}-covariance{i}).')/2));
    end
    metadata=design_study.make_metadata(provider);
    result = struct( ...
        'schema_version','stage9_sequential_information_v1', ...
        'case_id',provider.case_ids{caseIndex}, ...
        'sequence',sequenceName, ...
        'design_names',{designNames}, ...
        'labels',{labels}, ...
        'full_information',fullInformation, ...
        'q_information',qInformation, ...
        'full_increment',fullIncrement, ...
        'q_increment',qIncrement, ...
        'full_trace',fullTrace, ...
        'q_trace',qTrace, ...
        'mean_posterior_mean_recovery_error_u',meanRecovery, ...
        'coverage_95',coverage, ...
        'mean_normalized_posterior_sd',meanNormalizedWidth, ...
        'minimum_covariance_reduction_eigenvalue',minimumPSD, ...
        'nested_monotonicity_enforced',false, ...
        'observed_information_increments_nonnegative', ...
            all(fullIncrement>=-tolerance)&&all(qIncrement>=-tolerance), ...
        'observed_covariance_reduction_psd', ...
            all(minimumPSD(2:end)>=-tolerance), ...
        'metadata',metadata);
end
