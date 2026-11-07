function row = write_cell_draws(cfg, folder, cellRecord, provider, partner, missingReason, condition, sourceName)
%WRITE_CELL_DRAWS The full draws of both replicates of one cell's provider, in the format of thesis_results/.
%   ROW = study.write_cell_draws(CFG, FOLDER, CELLRECORD, PROVIDER, PARTNER,
%   MISSINGREASON, CONDITION) writes FOLDER/case_<id>.mat with the variable
%   draws, schema shipped_posterior_draws_v3 (the format of
%   thesis_results/fixed/<04|07>/data/draws; v3 adds
%   the log-likelihood to v2):
%     the cell (cellID, caseID, scenario, design, conditionCode, conditionTag,
%     state, certified, sampler, stepCount), providerReplicateID, the model
%     coordinates (parameterNames, bounds, truth, observation), for a
%     conditional cell its free and fixed parameters and the condition (code,
%     id, tag, label, parameter indices, role, scenarios), the
%     certification pointer of a certified provider, and replicates(k) for
%     each replicate of the provider's level: replicateID, walkers,
%     retainedIterations, drawsPhysical (every retained draw at full
%     precision: the retained sample array flattened walker by walker, in
%     model coordinates; conditional cells: the four coordinates with the
%     fixed ones at the truth), drawsFree (conditional cells: the inferred
%     coordinates), logLikelihood (draws x 1: the log-likelihood the sampler
%     computed for each retained draw, row by row with drawsPhysical; the
%     request's stored evaluations of its retained steps, no new model
%     evaluation; logLikelihoodSource 'sampler'. The prior is uniform inside
%     the bounds, so the log-posterior is logLikelihood plus a constant),
%     health, request and source (the posterior file).
%   PROVIDER is either the certified provider
%   (inversion.load_certified_posterior or
%   inversion.load_conditional_certified_posterior; state certified) or the
%   healthy completed fallback of a cell that was not certified, with the
%   field providerEvidence (sampler, replicateID, stepCount), as
%   confirmation.load_available_posterior returns it (state
%   non_certified_fallback, no certification pointer). PARTNER is the other
%   replicate of the provider's level (inversion.load_posterior_artifact or
%   load_conditional_posterior_artifact), or [] when that replicate has no
%   posterior; MISSINGREASON then says why. CONDITION is the conditional
%   condition (inversion.conditional_inversion_conditions), or [] for a
%   canonical cell.
%   SOURCENAME (optional) records a saved file by a function of its path;
%   by default the path relative to the run folder CFG.native.run.
%   ROW is the cell's row of draws/index.csv
%   (study.cell_draws_columns); its File is relative to the draws
%   folder that holds FOLDER.
%   Files carry no hashes.
%   Side effects: writes the file, replacing an earlier version.

    if nargin < 8 || isempty(sourceName), sourceName = @(p) run_relative(cfg, p); end
    conditional = ~isempty(condition);
    certified = isfield(provider, 'certification') && ~isempty(provider.certification);
    if certified
        pointer = provider.certification;
        chosen = pointer.provider;
    else
        pointer = struct([]);
        chosen = provider.providerEvidence;
    end
    replicates = replicate(provider, conditional, sourceName);
    if ~isempty(partner)
        replicates(2) = replicate(partner, conditional, sourceName);
        [~, order] = sort([replicates.replicateID]);
        replicates = replicates(order);
    end
    D = struct();
    D.schemaVersion = 'shipped_posterior_draws_v3';
    D.cellID = char(cellRecord.cellID);
    D.caseID = double(cellRecord.caseID);
    D.scenario = char(cellRecord.scenario);
    D.design = char(cellRecord.design);
    D.conditionCode = '';
    D.conditionTag = '';
    if conditional
        D.conditionCode = char(condition.code);
        D.conditionTag = char(condition.tag);
    end
    D.state = 'certified';
    if ~certified, D.state = 'non_certified_fallback'; end
    D.certified = certified;
    D.sampler = char(chosen.sampler);
    D.stepCount = double(chosen.stepCount);
    D.providerReplicateID = double(chosen.replicateID);
    D.parameterNames = cellstr(string(provider.parameterNames));
    D.bounds = double(provider.bounds);
    D.truth = double(provider.truth);
    D.observation = double(provider.observation);
    D.coordinateNote = ['Model coordinates: m3_f_RD, m3_e_RD, log10(k0_RD), ' ...
        'Thickness_RD (log10 permeability, not k0 itself).'];
    if conditional
        % The certification pointer names the free and fixed coordinates; a
        % healthy fallback has its posterior record's.
        indices = provider;
        if certified, indices = pointer; end
        D.freeParameterIndices = double(indices.freeParameterIndices(:).');
        D.fixedParameterIndices = double(indices.fixedParameterIndices(:).');
        D.freeParameterNames = cellstr(string(provider.freeParameterNames));
        D.parameterRoles = cellstr(string(provider.parameterRoles));
        D.freeBounds = double(provider.freeBounds);
        D.condition = condition_record(provider.condition);
    end
    D.replicates = replicates;
    % Each replicate's logLikelihood holds the evaluations the sampler stored for its retained states.
    D.logLikelihoodSource = 'sampler';
    D.missingReplicateReason = '';
    if isempty(partner), D.missingReplicateReason = char(string(missingReason)); end
    D.certification = pointer;
    D.certificationSource = '';
    if certified, D.certificationSource = sourceName(provider.certificationPath); end
    target = fullfile(folder, sprintf('case_%d.mat', D.caseID));
    if ~isfolder(folder), mkdir(folder); end
    utils.atomic_save_struct(target, struct('draws', D), '-v7');
    info = dir(target);
    k = [replicates.replicateID] == D.providerReplicateID;
    other = replicates(~k);
    partnerOf = @(field) "";
    if ~isempty(other), partnerOf = @(field) string(other(1).(field)); end
    row = table(string(D.cellID), D.caseID, string(D.scenario), string(D.design), ...
        string(D.conditionCode), string(D.state), D.certified, D.stepCount, ...
        D.providerReplicateID, string(strjoin(string([replicates.replicateID]), ';')), ...
        replicates(1).walkers, replicates(1).retainedIterations, ...
        size(replicates(1).drawsPhysical, 1), string(draws_relative(target)), info.bytes, ...
        string(replicates(k).source), partnerOf('source'), ...
        string(D.missingReplicateReason), 'VariableNames', study.cell_draws_columns());
end

function R = replicate(A, conditional, sourceName)
%REPLICATE One replicate's retained draws and records, as the sampler saved them.
    sampleArray = double(A.sampleArray);
    [iterations, ~, walkers] = size(sampleArray);
    R = struct();
    R.replicateID = double(A.request.replicateID);
    R.walkers = walkers;
    R.retainedIterations = iterations;
    if conditional
        R.drawsPhysical = double(A.drawsCanonicalCoordinates);
        R.drawsFree = double(A.drawsFree);
    else
        % Iteration i of walker w is row i + (w-1)*iterations, as the sampler saved it.
        R.drawsPhysical = reshape(permute(sampleArray, [1 3 2]), [], size(sampleArray, 2));
        assert(isequal(R.drawsPhysical, double(A.drawsPhysical)), 'study:cell_draws:DrawOrder', ...
            'The saved draws of %s are not the flattened sample array.', A.paths.posteriorPath);
    end
    assert(size(R.drawsPhysical, 1) == iterations * walkers, 'study:cell_draws:DrawCount', ...
        'The draws of %s are not the retained iterations of every walker.', A.paths.posteriorPath);
    R.logLikelihood = retained_log_likelihood(A, sampleArray);
    R.health = A.health;
    R.request = A.request;
    R.source = sourceName(A.paths.posteriorPath);
end

function value = retained_log_likelihood(A, sampleArray)
%RETAINED_LOG_LIKELIHOOD The log-likelihood the sampler computed for each retained state, as a column.
%   The request's checkpoint keeps every state of the run (rawSample, step x
%   parameter x walker) and the sampler's log-likelihood of each
%   (logLikelihoodTrace, step x walker); the retained states are the last
%   steps (the burn-in removed), which SAMPLEARRAY holds. Row i +
%   (w-1)*iterations is iteration i of walker w, as in drawsPhysical. No
%   model is evaluated.
    state = A.checkpointState;
    raw = double(state.rawSample);
    trace = double(state.logLikelihoodTrace);
    [iterations, ~, walkers] = size(sampleArray);
    burnIn = size(raw, 1) - iterations;
    assert(burnIn >= 0 && isequal(size(trace), [size(raw, 1) walkers]) && ...
        isequal(raw(burnIn + 1:end, :, :), sampleArray), 'study:cell_draws:LogLikelihood', ...
        'The sampler''s log-likelihood trace of %s does not belong to its retained draws.', ...
        A.paths.posteriorPath);
    value = reshape(trace(burnIn + 1:end, :), [], 1);
    assert(all(isfinite(value)), 'study:cell_draws:LogLikelihood', ...
        'The sampler''s log-likelihood of %s is not finite at every retained draw.', A.paths.posteriorPath);
end

function p = draws_relative(target)
%DRAWS_RELATIVE The file's path below the draws folder that holds it, with '/'.
    parts = strsplit(strrep(target, '\', '/'), '/');
    at = find(strcmp(parts, 'draws'), 1, 'last');
    assert(~isempty(at), 'study:cell_draws:Folder', '%s is not below a draws folder.', target);
    p = strjoin(parts(at + 1:end), '/');
end

function p = run_relative(cfg, pathValue)
%RUN_RELATIVE A path inside the run folder, relative to it with '/'.
%   Both paths are canonicalized (utils.absolute_path) as the campaign code
%   canonicalizes its stage folder.
    run = utils.absolute_path(cfg.native.run);
    pathValue = utils.absolute_path(pathValue);
    assert(strncmpi(pathValue, [run filesep], numel(run) + 1), 'study:cell_draws:OutsideRun', ...
        '%s is not inside the run folder %s.', pathValue, run);
    p = strrep(pathValue(numel(run) + 2:end), '\', '/');
end

function C = condition_record(condition)
%CONDITION_RECORD The condition as the draw files record it (shipped_posterior_draws_v2 and v3).
%   Its code, id, tag and label, the free and fixed parameter indices, the
%   source of the fixed values, its role, scenarios and reference flags: the
%   fields of the thesis draws, so that every draw file has one format (the
%   settings' table, A.9, adds the description, names and mask, which the
%   run record keeps).
    C = struct();
    for name = {'code', 'id', 'tag', 'label', 'freeParameterIndices', 'fixedParameterIndices', ...
            'fixedValueSource', 'role', 'scheduledScenarios', 'canonicalReference', ...
            'supplementaryExecution'}
        C.(name{1}) = condition.(name{1});
    end
end
