function P = posterior_provider_provenance(A)
%POSTERIOR_PROVIDER_PROVENANCE The certification record of a loaded posterior provider.
%   P = recovery.posterior_provider_provenance(A) returns A.certification
%   with the logical field certified (from the record, or from its
%   certification mechanism in records that do not state it).
%   Side effects: none.
    assert(isfield(A,'certification'), ...
        'recovery:posterior_provider_provenance:Certification', ...
        'The loaded posterior carries no certification record.');
    P=A.certification;
    if isfield(A.certification,'certified')
        P.certified=logical(A.certification.certified);
    else
        P.certified=strcmp(P.certificationMechanism, ...
            'CERTIFIED_AIES_REPLICATE_AGREEMENT');
    end
end
