function seed = surrogate_audit(cfg, purpose, key, numbers)
%SURROGATE_AUDIT The seed of one random draw of the fixed surrogate audit.
%   SEED = seeds.surrogate_audit(CFG, PURPOSE, KEY, NUMBERS) returns the
%   seed of the audit's draw PURPOSE for the request KEY, a struct with the
%   request's Output, Repeat, Fold, TrainingSize, Kernel and Candidate as
%   far as they apply (the columns of config/seeds/surrogate_audit_seeds.csv,
%   cfg.seeds.tables.surrogateAudit, which records every seed of the thesis
%   audit). A request without a recorded seed (another number of repeats,
%   folds or training sizes) takes the seed of the rule
%   cfg.seeds.rules.surrogateAudit:
%       base + purpose * (the purpose's number) + output * NUMBERS.output
%            + repeat * NUMBERS.repeat + index * NUMBERS.index.
%   The purposes and their numbers: kernel_cv_fold_assignment (1),
%   kernel_cv_fit (2), same_data_probe (3), same_data_fit (4),
%   calibration_fold_assignment (5), convergence_partition (6),
%   convergence_gp_fit (7), convergence_pce_fit (8),
%   calibration_cluster_bootstrap (9), residual_correlation_bootstrap (10).
%   NUMBERS gives the output, the repeat and the index (the fold, or the
%   position of the training size in the audit's list of sizes), 0 where
%   one does not apply; for the residual-correlation bootstrap the kernel's
%   position (output), the candidate's position (repeat) and the fold
%   (index).
%   Side effects: none (reads the recorded table once per session).

    purposes = {'kernel_cv_fold_assignment', 'kernel_cv_fit', 'same_data_probe', ...
        'same_data_fit', 'calibration_fold_assignment', 'convergence_partition', ...
        'convergence_gp_fit', 'convergence_pce_fit', 'calibration_cluster_bootstrap', ...
        'residual_correlation_bootstrap'};
    purposeNumber = find(strcmp(purposes, purpose));
    assert(isscalar(purposeNumber), 'seeds:surrogate_audit:Purpose', ...
        'Unknown surrogate-audit seed purpose %s.', purpose);
    full = struct('Purpose', purpose, 'Output', '', 'Repeat', '', 'Fold', '', ...
        'TrainingSize', '', 'Kernel', '', 'Candidate', '');
    names = fieldnames(key);
    for k = 1:numel(names)
        assert(isfield(full, names{k}), 'seeds:surrogate_audit:Key', ...
            'The surrogate-audit seed table has no column %s.', names{k});
        full.(names{k}) = key.(names{k});
    end
    seed = seeds.recorded(cfg, 'surrogateAudit', full);
    if isnan(seed)
        numbers.purpose = purposeNumber;
        seed = seeds.rule(cfg.seeds.rules.surrogateAudit, numbers);
        seeds.check_new(cfg, seed, sprintf('the surrogate audit''s %s (output %d, repeat %d, index %d)', ...
            purpose, numbers.output, numbers.repeat, numbers.index));
    end
end
