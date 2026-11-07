function path = provider_evidence_path(A)
%PROVIDER_EVIDENCE_PATH The path of the certification record of a loaded posterior provider.
%   PATH = recovery.provider_evidence_path(A): A.certificationPath, which the
%   loaders set (inversion.load_certified_posterior in a rerun,
%   study.load_shipped_posterior in reproduce mode); renderers record it as a
%   figure's source.
%   Side effects: none.
    path=A.certificationPath;
end
