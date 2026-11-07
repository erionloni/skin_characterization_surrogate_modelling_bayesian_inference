function generalized_dataset(cfg, ~)
%GENERALIZED_DATASET Step 'dataset' of the generalized route: the 939-case dataset and its split.
%   study.steps.generalized_dataset(CFG, STEPSINCALL) reads the generalized
%   dataset table (CFG.realExtended.csv, setting generalized.dataset.file:
%   one row per designed case), reconstructs the case and
%   probe registries, applies the quality control, classifies complete and
%   partial cases, draws the 857 development / 82 external split and writes,
%   into <run>/generalized/01_dataset/data: dataset.mat,
%   the processed, registry, split, exclusion and feasibility tables and the
%   core contract and the dataset reports in metadata/. CFG comes from
%   study.native_config. The figures it draws while computing stay in the
%   run's work folder; the figures step renders the published ones.
%   Computation: about 1-1.5 min. The build is data.build_dataset
%   (data.build_generalized_dataset).
%   Side effects: writes the outputs above below the run folder.
    data.build_dataset(cfg);
end
