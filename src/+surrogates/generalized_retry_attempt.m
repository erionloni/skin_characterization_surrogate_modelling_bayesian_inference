function attempt = generalized_retry_attempt(cfg)
%GENERALIZED_RETRY_ATTEMPT The retry attempt of the generalized refit's fits.
%   ATTEMPT = surrogates.generalized_retry_attempt(CFG) is
%   CFG.realExtended.stage2RetryAttempt (study.project_config option
%   'GeneralizedRetryAttempt', default 0). Attempt 0 is never overwritten;
%   to retry a failed output, pass a larger nonnegative integer. The new
%   attempt gets its own checkpoints (named by the attempt).
%   Side effects: none.

    attempt=0;
    if nargin>0&&isfield(cfg,'realExtended')&& ...
            isfield(cfg.realExtended,'stage2RetryAttempt')
        attempt=double(cfg.realExtended.stage2RetryAttempt);
    end
    assert(isscalar(attempt)&&isfinite(attempt)&&attempt>=0&& ...
        attempt==floor(attempt), ...
        'surrogates:generalized_retry_attempt:InvalidAttempt', ...
        'The generalized retry attempt must be a nonnegative integer.');
end
