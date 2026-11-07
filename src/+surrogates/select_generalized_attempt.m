function index = select_generalized_attempt(records, family)
%SELECT_GENERALIZED_ATTEMPT Select one terminal immutable retry attempt.
%   The newest completed attempt wins. A later failed retry cannot displace
%   a completed model. When none completed, the newest failed attempt is
%   returned so the failure remains explicit and resumable.
%   INDEX = surrogates.select_generalized_attempt(RECORDS, FAMILY) returns
%   the index of that attempt among the checkpoint records RECORDS of the
%   family 'gp' or 'pce'.
%   Side effects: none.

    assert(~isempty(records),'surrogates:select_generalized_attempt:Empty', ...
        'At least one terminal record is required.');
    attempts=nan(numel(records),1);
    completed=false(numel(records),1);
    for i=1:numel(records)
        record=records(i);
        completed(i)=strcmp(record.executionStatus,'completed');
        if strcmp(family,'gp')
            assert(isfield(record,'settings')&& ...
                isfield(record.settings,'retryAttempt'), ...
                'surrogates:select_generalized_attempt:GPAttempt', ...
                'GP record lacks retry-attempt provenance.');
            attempts(i)=record.settings.retryAttempt;
        elseif strcmp(family,'pce')
            assert(isfield(record,'policy')&& ...
                isfield(record.policy,'retryAttempt'), ...
                'surrogates:select_generalized_attempt:PCEAttempt', ...
                'PCE record lacks retry-attempt provenance.');
            attempts(i)=record.policy.retryAttempt;
        else
            error('surrogates:select_generalized_attempt:Family', ...
                'Unknown surrogate family: %s',family);
        end
    end
    eligible=true(size(completed));
    if any(completed),eligible=completed;end
    newest=max(attempts(eligible));
    candidates=find(eligible&attempts==newest);
    assert(isscalar(candidates), ...
        'surrogates:select_generalized_attempt:Ambiguous', ...
        'Multiple terminal checkpoints share the selected retry attempt.');
    index=candidates;
end
