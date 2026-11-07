function outcome = generalized_surrogates(cfg, ~)
%GENERALIZED_SURROGATES Step 'surrogates' of the generalized route: refit the GPs and PCEs.
%   OUTCOME = study.steps.generalized_surrogates(CFG, STEPSINCALL) fits, on
%   the development cases of the dataset CFG.files.dataset, one Matern-3/2
%   GP and one PCE per closing pressure under the approved fit policy
%   (setting generalized.surrogates.fitPolicy, config/generalized_gp_fit_policy.json: outputs 1
%   and 3 select the best of five declared starts at 100 iterations; the
%   other outputs are single fits) with the thesis seeds of
%   config/seeds/surrogate_fit_seeds.csv. Each fit is preceded by its 5-fold
%   cross-validation on development cases only. The ensembles are written
%   to <run>/generalized/02_surrogates/data as in thesis_results/:
%     surrogates/gp/ensembles, surrogates/pce/ensembles   the two ensembles
%     surrogates/*.csv                 training-only CV, training status,
%                                      PCE complexity, GP hyperparameters,
%                                      fit seeds
%     models/gp_surrogate.mat, models/pce_surrogate.mat
%                                      resolvers of the two ensembles
%   Per-output checkpoints, candidate fits, progress, logs and the stage
%   report stay in <run>/_run/surrogates (CFG.paths.surrogateWork).
%   CFG.native.surrogateOutputs selects the work of this call: 'all' fits
%   every output that has no checkpoint yet and assembles the ensembles;
%   output indices fit only those outputs (GP and PCE; for example one
%   process or cluster job per output), and a later call with 'all'
%   assembles them.
%   The later steps do not use this refit: they bind the approved package
%   (settings B.3), because the approved calibration belongs to the
%   approved model.
%   OUTCOME has fields published (true once the ensembles are written) and
%   details (kept in the run record).
%   Computation: about 1.5 h at the thesis settings (outputs 1 and 3 about
%   30 min each, the others 1-4 min); minutes with the demonstration budget
%   CFG.gp.demonstrationIterations. Runs surrogates.fit_generalized.
%   Side effects: writes the outputs above below the run folder.

    outputs = cfg.native.surrogateOutputs;
    state = rng;
    restore = onCleanup(@() rng(state));
    rng(cfg.seed, 'twister');   % as the pre-publication script s02_train_surrogates
    if ischar(outputs)
        surrogates.fit_generalized(cfg);
    else
        for j = reshape(outputs, 1, [])
            surrogates.fit_generalized(cfg, 'WorkerKind', 'gp', 'WorkerOutput', j);
            surrogates.fit_generalized(cfg, 'WorkerKind', 'pce', 'WorkerOutput', j);
        end
    end
    clear restore
    iterations = [];
    if isfield(cfg.gp, 'demonstrationIterations'), iterations = cfg.gp.demonstrationIterations; end
    [~, name, extension] = fileparts(cfg.emulatorErrorCalibration.artifact_path);
    outcome = struct('published', ischar(outputs), 'details', struct( ...
        'later_steps_use', sprintf(['the approved package: its calibration %s belongs to ' ...
            'the approved model, not to this refit'], [name extension]), ...
        'demonstration_gp_iterations', iterations));
    if ischar(outputs)
        fprintf('[study] surrogates: GP and PCE ensembles of six outputs written.\n');
    else
        fprintf(['[study] surrogates: output(s) %s fitted; call again with ' ...
            '''SurrogateOutputs'',''all'' to fit the rest and write the ensembles.\n'], ...
            mat2str(outputs));
    end
end
