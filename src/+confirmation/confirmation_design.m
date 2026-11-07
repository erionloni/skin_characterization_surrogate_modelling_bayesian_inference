function design = confirmation_design(cfg)
%CONFIRMATION_DESIGN The confirmation experiment of the settings: materials x protocols.
%   DESIGN = confirmation.confirmation_design(CFG) builds the design of the
%   confirmation from the settings (B.7; CFG.stage9bConfirmation):
%     materials  the materials: CaseIDs of the fixed dataset (A.1,
%                CFG.realData.csv) in the order of the settings ('all': every
%                case of the dataset), with their parameter values as the
%                truths: m3_f_RD, m3_e_RD, k0_RD (physical, as read),
%                log10_k0_RD (log10 of k0_RD) and Thickness_RD;
%     protocols  one row per protocol: ProtocolIndex, Protocol (label),
%                ProtocolRole ('default' for the reference, the first row;
%                'selected' for the others), ObjectiveID and ComparisonRole of
%                the screening objective it targets, SignedRate_kPa_s,
%                RateMagnitude_kPa_s, Log10AbsRate (the GP coordinate,
%                log10 of the magnitude), Hold_s and Pause_s. With
%                'from_screening': the default protocol (B.1) and, for each
%                objective of the settings, the protocol ranked first among
%                the eligible protocols of the operational covariance case of
%                the screening results (CFG.stage9bConfirmation.rankingsFile),
%                with the exact rate, hold and pause of the protocol grid
%                (screening.build_candidate_registry), labelled by the
%                objective's confirmation role (joint_focused,
%                permeability_focused, dissipation_focused);
%     rows       one row per material and protocol (DesignIndex; materials
%                in order, each with every protocol in order): the truth and
%                the protocol;
%     solves     the run list: one COMSOL solve per row and probe (D2, then
%                D6), with its RunID (case<CaseID>_<protocol>_<probe>) and
%                its COMSOL inputs (m3_f_RD, m3_e_RD, k0_RD, Thickness_RD,
%                SignedRate_kPa_s, Hold_s, Pause_s). The observations of a
%                solve join it by these values (confirmation.
%                import_confirmation_observations).
%   The design refuses a CaseID that is not in the dataset or repeated, a
%   truth outside the prior bounds, a protocol outside the protocol bounds of
%   the GP (B.1) and two protocols with the same values.
%   Side effects: none.

    C = cfg.stage9bConfirmation;
    materials = material_truths(cfg, C.materials);
    protocols = protocol_table(cfg, C);
    nM = height(materials); nP = height(protocols);
    [p, m] = ndgrid(1:nP, 1:nM);
    rows = [table((1:nM * nP).', 'VariableNames', {'DesignIndex'}), ...
        materials(m(:), :), protocols(p(:), :)];
    probes = ["D2"; "D6"];
    [probe, row] = ndgrid(1:2, 1:height(rows));
    r = rows(row(:), :);
    solves = [table((1:numel(row)).', "case" + string(r.MaterialCaseID) + "_" + r.Protocol + "_" + ...
        probes(probe(:)), r.DesignIndex, r.MaterialCaseID, r.Protocol, probes(probe(:)), ...
        'VariableNames', {'SolveIndex', 'RunID', 'DesignIndex', 'MaterialCaseID', 'Protocol', 'Probe'}), ...
        r(:, confirmation.comsol_inputs())];
    design = struct('materials', materials, 'protocols', protocols, 'rows', rows, 'solves', solves);
end

function T = material_truths(cfg, selection)
%MATERIAL_TRUTHS The materials of the settings with their values in the fixed dataset.
    D = readtable(cfg.realData.csv, 'Delimiter', ',', 'TreatAsMissing', {'-', 'NA', 'N/A', 'nan', 'NaN'});
    ids = double(D.CaseID);
    if ischar(selection) || isstring(selection)
        selection = ids;
    end
    selection = reshape(double(selection), [], 1);
    [found, at] = ismember(selection, ids);
    assert(all(found), 'confirmation:confirmation_design:Materials', ...
        'The confirmation materials %s are not CaseIDs of the fixed dataset %s (settings B.7, A.1).', ...
        mat2str(selection(~found).'), cfg.realData.csv);
    assert(numel(unique(selection)) == numel(selection), 'confirmation:confirmation_design:Materials', ...
        'The confirmation materials repeat a CaseID (settings B.7).');
    k0 = D.k0_RD(at);
    T = table(selection, D.m3_f_RD(at), D.m3_e_RD(at), k0, log10(k0), D.Thickness_RD(at), ...
        'VariableNames', {'MaterialCaseID', 'm3_f_RD', 'm3_e_RD', 'k0_RD', 'log10_k0_RD', 'Thickness_RD'});
    bounds = cfg.realExtended.learningBounds(1:4, :);
    truth = T{:, {'m3_f_RD', 'm3_e_RD', 'log10_k0_RD', 'Thickness_RD'}};
    inside = all(isfinite(truth), 2) & all(truth >= bounds(:, 1).' & truth <= bounds(:, 2).', 2);
    assert(all(inside), 'confirmation:confirmation_design:Truth', ...
        'The truths of the materials %s lie outside the prior bounds (settings B.1).', ...
        mat2str(T.MaterialCaseID(~inside).'));
end

function T = protocol_table(cfg, C)
%PROTOCOL_TABLE The protocols of the settings, or the screening leaders ('from_screening').
%   The GP coordinate of a protocol is log10 of its rate's magnitude, as for
%   the default protocol (B.1), whichever way the protocol is given.
    registry = screening.objective_registry();
    if ischar(C.protocols) || isstring(C.protocols)
        [labels, objectives, rates, holds, pauses] = from_screening(cfg, C.objectives, registry);
    else
        P = C.protocols;
        labels = string(P(:, 1)); objectives = string(P(:, 2));
        rates = cell2mat(P(:, 3)); holds = cell2mat(P(:, 4)); pauses = cell2mat(P(:, 5));
    end
    n = numel(labels);
    roles = repmat("selected", n, 1); roles(1) = "default";
    comparison = strings(n, 1);
    for k = 2:n
        comparison(k) = registry.ConfirmationRole(registry.ObjectiveID == objectives(k));
    end
    T = table((1:n).', labels, roles, objectives, comparison, rates, -rates, log10(-rates), holds, pauses, ...
        'VariableNames', {'ProtocolIndex', 'Protocol', 'ProtocolRole', 'ObjectiveID', ...
        'ComparisonRole', 'SignedRate_kPa_s', 'RateMagnitude_kPa_s', 'Log10AbsRate', 'Hold_s', 'Pause_s'});
    bounds = cfg.realExtended.learningBounds(5:7, :);
    X = [T.Log10AbsRate T.Hold_s T.Pause_s];
    inside = all(X >= bounds(:, 1).' & X <= bounds(:, 2).', 2);
    assert(all(inside), 'confirmation:confirmation_design:ProtocolBounds', ...
        ['The protocols %s lie outside the protocol bounds of the GP (settings B.1: |rate| %g to ' ...
         '%g kPa/s, hold %g to %g s, pause %g to %g s).'], strjoin(T.Protocol(~inside), ', '), ...
        10 ^ bounds(1, 1), 10 ^ bounds(1, 2), bounds(2, 1), bounds(2, 2), bounds(3, 1), bounds(3, 2));
    assert(size(unique(X, 'rows'), 1) == n, 'confirmation:confirmation_design:ProtocolRepeated', ...
        'Two confirmation protocols have the same rate, hold and pause (settings B.7).');
end

function [labels, objectives, rates, holds, pauses] = from_screening(cfg, objectiveList, registry)
%FROM_SCREENING The default protocol and the screening leader of every objective.
%   The reference is the default protocol (B.1). The leader of an objective
%   is the protocol ranked first among the eligible protocols of the
%   operational covariance case (the screen's primary view), found in the
%   protocol grid by its index, with the grid's exact rate, hold and pause;
%   its label is the objective's confirmation role ('selected_joint' gives
%   'joint_focused').
    file = cfg.stage9bConfirmation.rankingsFile;
    assert(isfile(file), 'confirmation:confirmation_design:Rankings', ...
        ['The protocols ''from_screening'' need the screening rankings %s; run the steps ' ...
         'objective_supplement and rankings, or give the protocols explicitly (settings B.7).'], file);
    R = readtable(file, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    grid = screening.build_candidate_registry(cfg);
    objectiveList = string(objectiveList(:));
    index = zeros(numel(objectiveList), 1);
    for k = 1:numel(objectiveList)
        hit = R.ObjectiveID == objectiveList(k) & R.CovarianceCase == "operational_measurement_plus_emulator" & ...
            logical(R.Eligible) & double(R.Rank) == 1;
        assert(nnz(hit) == 1, 'confirmation:confirmation_design:Leader', ...
            'The screening rankings %s have no single leader for the objective %s.', file, objectiveList(k));
        index(k) = double(R.CandidateIndex(hit));
    end
    [found, at] = ismember(index, double(grid.CandidateIndex));
    assert(all(found), 'confirmation:confirmation_design:Leader', ...
        'A screening leader is not a protocol of the protocol grid (settings B.6).');
    [~, role] = ismember(objectiveList, registry.ObjectiveID);
    labels = ["default"; extractAfter(registry.ConfirmationRole(role), "selected_") + "_focused"];
    objectives = [""; objectiveList];
    d = cfg.realExtended.defaultProtocol;
    rates = [d.suction_rate_kPa_s; grid.SignedRate_kPa_s(at)];
    holds = [d.hold_dur_s; grid.Hold_s(at)];
    pauses = [d.pause_dur_s; grid.Pause_s(at)];
end
