function W = switches(route)
%SWITCHES The run switches of one route: one per step and one per analysis inside a step.
%   W = study.switches(ROUTE) returns, for ROUTE 'fixed' or 'generalized', a
%   struct array with one element per switch of section 0.2 of the settings
%   file (s.run.<route>.<name>, true or false):
%     name       the step (study.steps) or the analysis
%     kind       'step' or 'analysis'
%     step       the step the analysis belongs to (a step: its own name)
%     requires   analyses of the same step that must run in the same call
%                (an analysis computed from another one's intermediate
%                results, not from its saved files)
%     renderers  the renderers (study.renderers names) that draw the
%                analysis's outputs; for a step whose outputs share an
%                analysis folder with other steps (the feature sensitivity
%                and accuracy, the parameter combinations) its own
%                renderers; {} for another step (its analysis folders'
%                renderers)
%   In reproduce mode a switch chooses what is rendered, in rerun mode what is
%   computed (study.resolve_settings, study.plan); an analysis runs only
%   inside its step. Switches choose analyses, never parts of the method:
%   health checks, certification and provider selection have no switch.
%   Side effects: none.

    steps = study.steps(route);
    W = arrayfun(@(r) entry(r.name, 'step', r.name, {}, step_renderers(route, r.name)), steps);
    switch char(route)
        case 'fixed'
            W = [W, ...
                entry('coverage_recovery', 'analysis', 'recovery', {}, ...
                    {'plotting.saved_coverage_figures', 'plotting.saved_posterior_summary_figures', ...
                     'plotting.saved_predictive_check_figures', 'plotting.saved_bound_sensitivity_table', ...
                     'plotting.saved_thesis_tables'}), ...
                entry('eigen_analysis', 'analysis', 'recovery', {}, ...
                    {'plotting.saved_posterior_eigendecomposition_figures'}), ...
                entry('feature_reconstruction', 'analysis', 'recovery', {}, ...
                    {'plotting.saved_feature_reconstruction_figures'}), ...
                entry('error_budget', 'analysis', 'recovery', {'feature_reconstruction'}, ...
                    {'plotting.saved_downstream_error_budget_figures'}), ...
                entry('second_mode_check', 'analysis', 'recovery', {}, ...
                    {'plotting.saved_second_mode_figures'})];
    end
end

function R = step_renderers(route, name)
%STEP_RENDERERS The renderers of a step whose outputs share an analysis folder with other steps.
    switch name
        case 'feature_sensitivity'
            R = {'plotting.saved_feature_sensitivity_figures'};
        case 'feature_accuracy'
            R = {'plotting.saved_feature_accuracy_figures'};
        case 'combinations'
            if strcmp(char(route), 'generalized')
                R = {'plotting.saved_confirmation_combination_figures'};
            else
                R = {'plotting.saved_combination_figures'};
            end
        otherwise
            R = {};
    end
end

function w = entry(name, kind, step, requires, renderers)
    w = struct('name', name, 'kind', kind, 'step', step, 'requires', {requires}, ...
        'renderers', {renderers});
end
