function report = reproduce_thesis_results(varargin)
%REPRODUCE_THESIS_RESULTS Regenerate every thesis figure and table from the shipped results.
%   reproduce_thesis_results() reads thesis_results/<route>/<analysis>/data and
%   writes figures/ and tables/ for the fixed route and the generalized
%   route (the protocol screening and the confirmation included) into
%   runs/<run name>/, with the analysis READMEs, the results README.md
%   and run_record.json. No fitting, no MCMC, no UQLab.
%   reproduce_thesis_results('InPlace',true) regenerates, in the shipped
%   results themselves, every figures/ and tables/ folder, the analysis
%   READMEs and thesis_results/README.md (maintainers only; data/ is never
%   touched); the run record and the renderers' bookkeeping go to
%   runs/<run name>/.
%
%   Accepts the display options of study_settings.m ('Formats',
%   'Resolution', 'RunName', 'OutputFolder', 'Plan').
%   Side effects: changes the MATLAB path (src/ and config/); writes the
%   run folder (or thesis_results/ in place).
%   Computation: about 45 minutes.

    addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
    % One run folder holds all routes, like thesis_results/.
    runName = ['thesis_' char(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyyMMdd''T''HHmmss''Z'''))];
    entries = {'fixed', 'generalized'};
    report = struct();
    for i = 1:numel(entries)
        report.(entries{i}) = study.run(entries{i}, 'Mode', 'reproduce', ...
            'RunName', runName, varargin{:});
    end
end
