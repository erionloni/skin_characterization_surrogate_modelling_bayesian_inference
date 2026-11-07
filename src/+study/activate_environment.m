function environment = activate_environment(s)
%ACTIVATE_ENVIRONMENT Start UQLab for a rerun.
%   ENVIRONMENT = study.activate_environment(S) puts the repository and the
%   UQLab installation S.paths.uqlabRoot on the MATLAB path and starts UQLab
%   (utils.activate_uqlab). ENVIRONMENT records the MATLAB and UQLab
%   versions (provenance, not a check; the run
%   record writes the same line, study.run_record).
%   Side effects: changes the MATLAB path; starts UQLab.

    environment = utils.activate_uqlab(study.root(), s.paths.uqlabRoot, ...
        'ResetToDefault', false, 'StartUQLab', true);
end
