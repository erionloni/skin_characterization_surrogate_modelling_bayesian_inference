function c = inversion_campaign(runFolder)
%INVERSION_CAMPAIGN The inversion campaign of a run folder, or [] when it has none.
%   C = study.inversion_campaign(RUN) reads the preparation record that the
%   step 'inversion' writes (<RUN>/_run/inversion/campaign_preparation.json,
%   inversion.prepare_grid_campaign) and returns a struct with
%     caseIDs             the cases of the campaign, in grid order
%     cellCount           number of grid cells (cases x 3 scenarios x 6 designs)
%     demonstrationSteps  the shortened chain lengths of a demonstration
%                         campaign ('DemonstrationSteps'), [] for full chains
%   The steps that read the run's posteriors (recovery, design study)
%   analyse exactly these cases.
%   Side effects: none.
    c = [];
    p = fullfile(runFolder, '_run', 'inversion', 'campaign_preparation.json');
    if ~isfile(p), return; end
    r = jsondecode(fileread(p));
    steps = [];
    if isfield(r, 'demonstrationSteps'), steps = reshape(double(r.demonstrationSteps), 1, []); end
    c = struct('caseIDs', reshape(double(r.inversionCaseIDs), 1, []), ...
        'cellCount', double(r.cellCount), 'demonstrationSteps', steps);
end
