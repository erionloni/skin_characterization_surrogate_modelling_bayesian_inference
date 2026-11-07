function fixed_dataset(cfg, ~)
%FIXED_DATASET Step 'dataset' of the fixed route: the 452-case dataset and its split.
%   study.steps.fixed_dataset(CFG, STEPSINCALL) reads the model-ready CSV
%   (CFG.realData.csv), classifies complete and partial cases, draws the
%   constrained 391 development / 61 external split and writes, into
%   <run>/fixed/01_dataset/data: dataset.mat, dataset_audit.json,
%   split_manifest.csv, development_external_role_manifest.csv and the
%   per-output support tables. CFG comes from study.native_config.
%   Computation: seconds. The build is data.build_dataset.
%   Side effects: writes the outputs above below the run folder.
    data.build_dataset(cfg);
end
