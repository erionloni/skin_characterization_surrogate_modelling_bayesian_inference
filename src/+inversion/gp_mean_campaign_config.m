function campaignCfg = gp_mean_campaign_config(cfg)
%GP_MEAN_CAMPAIGN_CONFIG The configuration with which the canonical campaign code runs the GP-mean inversion.
%   CAMPAIGNCFG = inversion.gp_mean_campaign_config(CFG) returns CFG with the
%   folder and files of the canonical inversion campaign pointed at the
%   GP-mean campaign folder CFG.paths.gpMeanInversion
%   (<run>/_run/inversion/gp_mean_inversion):
%     paths.stage04             the campaign folder (posteriors/gp_mean_det/
%                               all_six/case_<id>/ below it)
%     files.inversionGrid       <campaign folder>/grid.csv
%     files.certificationIndex  <campaign folder>/certification/certification_index.csv
%     inversion.expectedCellCount  the number of GP-mean cells
%   The canonical campaign code then prepares, runs, certifies and records
%   the GP-mean cells there exactly as it does the canonical cells
%   (inversion.grid_campaign_support, inversion.run_grid_cell and the
%   reliability controller, inversion.save_certified_posterior,
%   inversion.load_certified_posterior, inversion.posterior_artifact_paths):
%   the same sampler, levels, replicates, health checks and certification.
%   The canonical campaign's folder and files are not touched.
%   Side effects: none.

    assert(isstruct(cfg)&&isscalar(cfg)&&isfield(cfg,'paths')&& ...
        isfield(cfg.paths,'gpMeanInversion')&&isfield(cfg,'gpMeanInversion'), ...
        'inversion:gp_mean_campaign_config:Configuration', ...
        'The GP-mean inversion folder (cfg.paths.gpMeanInversion) and settings A.13 are required.');
    root=cfg.paths.gpMeanInversion;
    campaignCfg=cfg;
    campaignCfg.paths.stage04=root;
    campaignCfg.files.inversionGrid=fullfile(root,'grid.csv');
    campaignCfg.files.certificationIndex=fullfile(root,'certification','certification_index.csv');
    campaignCfg.inversion.expectedCellCount=numel(cfg.gpMeanInversion.caseIDs);
end
