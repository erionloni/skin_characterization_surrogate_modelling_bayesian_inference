function line = environment_line(uqlabRoot)
%ENVIRONMENT_LINE One line with the MATLAB and UQLab versions (provenance, not a check).
%   LINE = utils.environment_line() names the running MATLAB release and the
%   UQLab on the MATLAB path; LINE = utils.environment_line(UQLABROOT) names
%   the UQLab in folder UQLABROOT (before UQLab is started). The UQLab
%   version is read from core/VERSION of that folder. Every run manifest and
%   the confirmation campaign's records carry this line; nothing compares
%   it with anything.
%   Example: 'MATLAB 25.2.0.3177638 (R2025b) Update 5; UQLab 2.3.0'.
%   Side effects: none.

    if nargin < 1 || isempty(uqlabRoot)
        uqlabRoot = utils.active_uqlab_root();
    end
    uqlab = 'UQLab not configured';
    if ~isempty(uqlabRoot)
        uqlab = 'UQLab (version file not found)';
        versionFile = fullfile(uqlabRoot, 'core', 'VERSION');
        if isfile(versionFile)
            uqlab = ['UQLab ' strtrim(fileread(versionFile))];
        end
    end
    line = sprintf('MATLAB %s; %s', version, uqlab);
end
