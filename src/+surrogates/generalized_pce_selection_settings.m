function settings = generalized_pce_selection_settings(policy, candidateTable)
%GENERALIZED_PCE_SELECTION_SETTINGS The settings of one output's PCE selection.
%   SETTINGS = surrogates.generalized_pce_selection_settings(POLICY,
%   CANDIDATETABLE) is the PCE policy POLICY (surrogates.generalized_pce_policy)
%   with the degree and q-norm of every candidate the selection compared, in
%   the order of CANDIDATETABLE (surrogates.train_generalized_pce). They are
%   part of the selection's request (surrogates.generalized_fit_request).
%   Side effects: none.
    settings=policy;
    settings.candidateDegrees=reshape(double(candidateTable.Degree),1,[]);
    settings.candidateQNorms=reshape(double(candidateTable.QNorm),1,[]);
end
