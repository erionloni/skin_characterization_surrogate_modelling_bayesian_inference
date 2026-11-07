function args = config_arguments(context, stage, varargin)
%CONFIG_ARGUMENTS The run-context arguments of study.project_config for one step.
%   ARGS = study.config_arguments(CONTEXT, STAGE) returns the name-value
%   list that describes the run of a step (the run context of
%   study.native_config) for configuration section STAGE (0 outside a
%   stage):
%     cfg = study.project_config(S, ARGS{:});
%   The scientific values come from the settings S; CONTEXT holds only what
%   the call decides: the route, the run root, whether the run resumes,
%   which steps of the call read held-out outcomes or run the audit or the
%   conditional inversion, and a call's explicit inversion cases ('Cases').
%
%   ARGS = study.config_arguments(CONTEXT, STAGE, NAME, VALUE, ...)
%   replaces single arguments, e.g. 'Resume',true for an action on saved
%   results.
%
%   Side effects: none.

    values = struct( ...
        'Route', char(string(context.route)), ...
        'RunRoot', char(string(context.runRoot)), ...
        'Stage', double(stage), ...
        'Resume', logical(context.resume), ...
        'RunSurrogateQualityAudit', logical(context.runSurrogateQualityAudit), ...
        'EvaluateExternalHoldout', logical(context.evaluateExternalHoldout), ...
        'InversionCaseIDs', reshape(double(context.inversionCaseIDs), 1, []), ...
        'RunConditionalInversion', logical(context.runConditionalInversion));
    assert(mod(numel(varargin), 2) == 0, 'study:config_arguments:Overrides', ...
        'Overrides must be name-value pairs.');
    for k = 1:2:numel(varargin)
        values.(char(varargin{k})) = varargin{k + 1};
    end
    names = fieldnames(values);
    args = cell(1, 2 * numel(names));
    args(1:2:end) = names;
    args(2:2:end) = struct2cell(values);
end
