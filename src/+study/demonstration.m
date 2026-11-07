function text = demonstration(runFolder)
%DEMONSTRATION The demonstration notice of a run folder ('' for thesis settings).
%   TEXT = study.demonstration(RUN) is not empty when a step of the run
%   folder RUN computed its results in an example run or at a reduced size
%   that the thesis results did not use (each recorded with the step in the
%   run record, study.run_record, so later calls that only render keep the
%   notice):
%     - an example run ('Scale','example'): a small version of the study;
%     - MCMC chains shortened by 'DemonstrationSteps': every result that
%       depends on those chains (inversion, recovery, design study and their
%       figures and tables) shows that the code runs, not thesis evidence;
%     - GP optimizations limited by 'DemonstrationGPIterations' (the
%       generalized refit): its models show that the code runs;
%     - a protocol screen of a subset ('ScreeningCandidates',
%       'ScreeningMaterials'; recorded as an incomplete design in the
%       screen's configuration): its rankings rank the subset only.
%   The READMEs of the run (study.write_results_readme, study.write_readme)
%   carry the notice; several reductions give one sentence each.
%   Side effects: none.
    example = false;
    notices = {};
    record = study.run_record('read', runFolder);
    completed = {};
    if ~isempty(record), completed = record.steps; end
    for k = 1:numel(completed)
        R = completed{k};
        if ~isfield(R, 'details') || ~isstruct(R.details), continue; end
        example = example || (isfield(R.details, 'scale') && strcmp(R.details.scale, 'example'));
        if isfield(R.details, 'demonstration_steps') && ~isempty(R.details.demonstration_steps)
            notices{end+1} = sprintf(['Demonstration: the MCMC chains of step ''%s'' were ' ...
                'shortened to %s steps per level. The results show that the code runs; they ' ...
                'are not thesis evidence.'], R.step, ...
                mat2str(reshape(double(R.details.demonstration_steps), 1, []))); %#ok<AGROW>
        end
        if isfield(R.details, 'demonstration_gp_iterations') && ...
                ~isempty(R.details.demonstration_gp_iterations)
            notices{end+1} = sprintf(['Demonstration: the GP optimizations of step ''%s'' ' ...
                'were limited to %d iterations. The models show that the code runs; they are ' ...
                'not thesis evidence.'], R.step, R.details.demonstration_gp_iterations); %#ok<AGROW>
        end
    end
    configuration = fullfile(runFolder, 'generalized', '05_protocol_screening', 'data', 'screen', ...
        'configuration', 'screening_configuration.json');
    if isfile(configuration)
        C = jsondecode(fileread(configuration));
        if isfield(C, 'complete_scientific_design') && ~logical(C.complete_scientific_design)
            notices{end+1} = ['Test run: the protocol screen covers a subset of the 730 ' ...
                'protocols and 1000 material points. Its rankings rank the subset only; they ' ...
                'are not the thesis screen.'];
        end
    end
    if example
        notices = [{['Example run (''Scale'',''example''): a small version of the study ' ...
            'that shows the code at work; its results are not thesis evidence.']}, notices];
    end
    text = strjoin(notices, ' ');
end
