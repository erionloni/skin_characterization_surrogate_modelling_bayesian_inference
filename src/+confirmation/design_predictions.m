function T=design_predictions(cfg,provider,design)
%DESIGN_PREDICTIONS The screen's six objectives of the confirmation protocols in the confirmation's observation designs.
%   T = confirmation.design_predictions(CFG, PROVIDER, DESIGN) evaluates the
%   proxy of the protocol screen (screening.evaluate_local_information with
%   the full covariance, screening.aggregate_objectives; policy
%   CFG.stage9bScreening, model provider PROVIDER) for the protocols of the
%   confirmation design DESIGN (confirmation.confirmation_design; the
%   reference protocol is the screen's default) at the screen's material
%   points (screening.build_material_lhs: its seed and size, settings B.6):
%   once with all six pressures, the screen's own design (the values of the
%   screen's rankings for the same protocols), and once for each other
%   observation design of the confirmation (settings B.7 design and
%   completePairsDesign: d2_only the three D2 pressures), so that the
%   improvement the proxy predicts refers to the design the posteriors
%   observe.
%   T: one row per design, protocol, covariance view and objective: Design,
%   Protocol, ProtocolRole, CovarianceCase, ObjectiveID, IsTargetObjective
%   (the objective the protocol was selected for), Eligible, MeanScore (the
%   objective's mean over the material points; smaller is better), Median,
%   Q90, DefaultScore, RelativeImprovement (over the default),
%   FractionImproved, FractionNearEqual, FractionWorse.
%   No sampler runs.
%   Side effects: none.
%   Computation: about a minute per design (the GP at the material points
%   and protocols).

    P=design.protocols;
    candidates=table(P.Protocol,double(P.ProtocolIndex),double(P.Log10AbsRate), ...
        double(P.Hold_s),double(P.Pause_s),true(height(P),1),P.ProtocolRole=="default", ...
        'VariableNames',{'CandidateID','CandidateIndex','Log10AbsRate','Hold_s','Pause_s', ...
        'WithinConfiguredBounds','IsDefault'});
    assert(nnz(candidates.IsDefault)==1,'confirmation:design_predictions:Default', ...
        'The confirmation design needs one reference protocol.');
    materials=screening.build_material_lhs(cfg);
    policy=cfg.stage9bScreening;
    designs=unique([{'all_six'},{char(string(cfg.stage9bConfirmation.design))}],'stable');
    if isfield(cfg.stage9bConfirmation,'completePairsDesign')&& ...
            ~isempty(cfg.stage9bConfirmation.completePairsDesign)
        designs=unique([designs,{char(string(cfg.stage9bConfirmation.completePairsDesign))}],'stable');
    end
    registry=screening.objective_registry();
    columns={'MeanScore','Median','Q90','DefaultScore','RelativeImprovement', ...
        'FractionImproved','FractionNearEqual','FractionWorse'};
    parts=cell(1,numel(designs));
    for d=1:numel(designs)
        outputs=inversion.design_registry(designs{d}).sourceOutputIndices;
        local=screening.evaluate_local_information(provider,candidates,materials,policy, ...
            'RetainFullCovariance',true,'Outputs',outputs);
        R=screening.aggregate_objectives(candidates,local,policy);
        [~,at]=ismember(R.CandidateID,P.Protocol);
        role=P.ProtocolRole(at);
        % The objective a focused protocol was selected for; the reference
        % protocol targets none.
        target=false(height(R),1);
        for i=1:height(R)
            target(i)=role(i)=="selected"&&any(registry.ConfirmationRole==P.ComparisonRole(at(i))& ...
                registry.ObjectiveID==R.ObjectiveID(i));
        end
        one=[table(repmat(string(designs{d}),height(R),1),string(R.CandidateID),role, ...
            string(R.CovarianceCase),string(R.ObjectiveID),target,logical(R.Eligible), ...
            'VariableNames',{'Design','Protocol','ProtocolRole','CovarianceCase','ObjectiveID', ...
            'IsTargetObjective','Eligible'}),R(:,columns)];
        % In the order of the design: protocol, then view and objective.
        [~,order]=sortrows([at,double(categorical(one.CovarianceCase)), ...
            arrayfun(@(o) find(registry.ObjectiveID==o),one.ObjectiveID)]);
        parts{d}=one(order,:);
    end
    T=vertcat(parts{:});
end
