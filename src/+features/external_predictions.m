function E = external_predictions(cfg)
%EXTERNAL_PREDICTIONS The surrogate assessment's predictions of the external cases, one row per case.
%   E = features.external_predictions(CFG) reads what the step
%   surrogate_assessment saved for the external cases (the guarded path of
%   the held-out outcomes): on the fixed route the prediction table of
%   CFG.files.validation and the cases' parameters from the dataset
%   CFG.files.dataset; on the generalized route the table
%   CFG.files.validationPredictions, which holds the inputs too. E holds,
%   for the n complete external cases (every output observed; the
%   assessment only predicts observed outputs):
%     caseIDs     n x 1
%     comsol      n x 6 closing pressures (mbar), the order of the outputs
%     gp, pce     n x 6 GP and PCE means
%     variance    n x 6 calibrated emulator variances (mbar^2)
%     inputs      n x M parameter (and protocol) values, model coordinates
%     inputNames  1 x M
%     rate        n x 1 magnitude of the suction rate (kPa/s): the default
%                 protocol's (settings B.1) on the fixed route
%     support     n x 6 the assessment's training-support class per output
%                 (generalized; "" on the fixed route)
%   Side effects: none.

    outputs = cellstr(string(cfg.outputNames));
    if strcmp(cfg.dataMode, 'real_extended')
        T = readtable(cfg.files.validationPredictions, 'Delimiter', ',', 'TextType', 'string', ...
            'VariableNamingRule', 'preserve');
        names = cellstr(string(cfg.realExtended.learningInputNames));
        caseIDs = unique(T.CaseID, 'stable');
        E = frame(caseIDs, outputs, names);
        for i = 1:numel(caseIDs)
            rows = T(T.CaseID == caseIDs(i), :);
            E = fill_case(E, i, rows, outputs);
            for m = 1:numel(names)
                E.inputs(i, m) = rows.(names{m})(1);
            end
            for k = 1:6
                E.support(i, k) = rows.SupportClass(strcmp(rows.Output, outputs{k}));
            end
        end
        E.rate = 10 .^ E.inputs(:, strcmp(names, 'log10_abs_suction_rate'));
    else
        S = utils.load_plain_mat(cfg.files.validation, 'validationPredictionTable');
        T = S.validationPredictionTable;
        D = utils.load_plain_mat(cfg.files.dataset, 'X_validation', 'validationCaseIDs');
        names = cellstr(string(cfg.paramNames));
        caseIDs = unique(double(T.CaseID), 'stable');
        E = frame(caseIDs, outputs, names);
        for i = 1:numel(caseIDs)
            rows = T(double(T.CaseID) == caseIDs(i), :);
            E = fill_case(E, i, rows, outputs);
            index = find(double(D.validationCaseIDs) == caseIDs(i));
            assert(isscalar(index), 'features:external_predictions:Case', ...
                'External case %d is not in the dataset''s external split.', caseIDs(i));
            E.inputs(i, :) = double(D.X_validation(index, :));
        end
        E.rate = repmat(cfg.features.accuracy.defaultRate, numel(caseIDs), 1);
    end
    complete = all(isfinite([E.comsol, E.gp]), 2) & all([E.comsol, E.gp] > 0, 2);
    assert(all(complete), 'features:external_predictions:Incomplete', ...
        ['%d external case(s) without all six positive pressures; the features need complete ' ...
         'cases (nothing is imputed).'], nnz(~complete));
end

function E = frame(caseIDs, outputs, names)
    n = numel(caseIDs);
    E = struct('caseIDs', double(caseIDs(:)), 'outputs', {outputs}, 'comsol', nan(n, 6), 'gp', nan(n, 6), ...
        'pce', nan(n, 6), 'variance', nan(n, 6), 'inputs', nan(n, numel(names)), 'inputNames', {names}, ...
        'rate', nan(n, 1), 'support', strings(n, 6));
end

function E = fill_case(E, i, rows, outputs)
%FILL_CASE The six outputs of one case, matched by output name (never by position).
    for k = 1:6
        hit = strcmp(cellstr(string(rows.Output)), outputs{k});
        assert(nnz(hit) == 1, 'features:external_predictions:Output', ...
            'External case %d: output %s found %d times.', E.caseIDs(i), outputs{k}, nnz(hit));
        E.comsol(i, k) = double(rows.COMSOL(hit));
        E.gp(i, k) = double(rows.GPMean(hit));
        E.pce(i, k) = double(rows.PCEMean(hit));
        E.variance(i, k) = double(rows.CalibratedEmulatorVariance(hit));
    end
end
