function D = import_comsol_csv(csvPath,P,cfg)
%IMPORT_COMSOL_CSV Import fixed-route evidence under the final-data contract.
%   Missing numerical outputs are NaN. Complete cases alone are eligible for
%   the deterministic external test; partial cases remain development-only and
%   contribute every available scalar target to its corresponding surrogate.
%   D = utils.import_comsol_csv(CSVPATH, P, CFG) accepts only the
%   configured fixed CSV (CFG.realData.csv) and returns
%   data.fixed_data_contract(CFG, P).
%   Side effects: none.

    assert(strcmp(utils.absolute_path(csvPath), ...
        utils.absolute_path(cfg.realData.csv)), ...
        'utils:import_comsol_csv:ConfiguredSource', ...
        'The importer accepts only the configured immutable fixed source.');
    D=data.fixed_data_contract(cfg,P);
end
