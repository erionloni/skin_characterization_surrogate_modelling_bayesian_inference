function contract = generalized_data_contract(caseRegistry,cfg,varargin)
%GENERALIZED_DATA_CONTRACT The generalized route's case contract from its case registry.
%   CONTRACT = data.generalized_data_contract(CASEREGISTRY, CFG) builds the
%   contract of data.final_data_contract from the generalized case registry
%   (one row per exact seven-input case: four material and three protocol
%   inputs, the six closing pressures and their availability). Exact
%   seven-input rows stay distinct protocol observations; the first four
%   inputs define the material split group, so that every protocol variant
%   of a material stays on one side of the complete-only external split.
%   No outcome-based exclusion is accepted.
%   CONTRACT: the contract, with the material and protocol input orders and
%   the source roles.
%   Side effects: none.

    assert(isempty(varargin),'data:generalized_data_contract:Options', ...
        'The generalized final-data contract accepts no outcome-based exclusions.');
    inputNames=cfg.realExtended.learningInputNames;
    outputNames=cfg.realExtended.outputNames;
    assert(numel(inputNames)==7&&numel(outputNames)==6, ...
        'data:generalized_data_contract:Dimensions', ...
        'The generalized contract requires seven inputs and six outputs.');
    assert(numel(unique(double(caseRegistry.CaseID)))==height(caseRegistry), ...
        'data:generalized_data_contract:CaseIDs', ...
        'The generalized case registry must contain unique CaseIDs.');

    X=double(caseRegistry{:,inputNames});
    Y=double(caseRegistry{:,outputNames});
    availabilityNames={'pcl1_D2_available','pcl2_D2_available', ...
        'pcl3_D2_available','pcl1_D6_available','pcl2_D6_available', ...
        'pcl3_D6_available'};
    assert(all(ismember(availabilityNames, ...
        caseRegistry.Properties.VariableNames)), ...
        'data:generalized_data_contract:OutputAvailabilitySchema', ...
        'The generalized case registry lacks six output-availability columns.');
    available=logical(caseRegistry{:,availabilityNames})&isfinite(Y)&Y>0;
    Y(~available)=NaN;
    % The split group of a case is its material (the first four inputs):
    % G0001, G0002, ... in the order of their first case (only the partition
    % is used).
    [~,~,material]=unique(X(:,1:4),'rows','stable');
    materialGroups=compose("G%04d",material);
    contract=data.final_data_contract(double(caseRegistry.CaseID), ...
        double(caseRegistry.CaseID),X,Y, ...
        'InputNames',inputNames,'OutputNames',outputNames, ...
        'SplitSeed',cfg.realExtended.splitSeed, ...
        'TestFraction',cfg.realExtended.testFraction, ...
        'SplitAlgorithmVersion', ...
            'complete_only_material_group_mt19937_v3', ...
        'SplitGroupIdentities',materialGroups);
    contract.materialParameterOrder=inputNames(1:4);
    contract.protocolInputOrder=inputNames(5:7);
    contract.noOutputImputation=true;
    contract.externalTestCompleteOnly=true;
    contract.partialCasesDevelopmentOnly=true;
    contract.sourceRoleRegistry=source_role_registry(caseRegistry,contract,cfg);
end

function registry=source_role_registry(C,contract,cfg)
    n=height(C);CaseID=double(C.CaseID);
    splitRole=repmat("unusable",n,1);
    MethodologicalRole=repmat("unusable",n,1);
    Classification=repmat("unusable",n,1);
    [foundMap,mapLoc]=ismember(CaseID,double(contract.sourceMap.SourceRow));
    assert(all(foundMap),'data:generalized_data_contract:SourceMap', ...
        'Every generalized source CaseID must occur in the final source map.');
    CanonicalCaseID=double(contract.sourceMap.CaseID(mapLoc));
    DuplicateGroup=string(contract.sourceMap.DuplicateGroup(mapLoc));
    SplitGroup=string(contract.sourceMap.SplitGroup(mapLoc));
    for i=1:n
        if isfinite(CanonicalCaseID(i))
            hit=find(double(contract.caseManifest.CaseID)==CanonicalCaseID(i),1);
            if ~isempty(hit)
                Classification(i)=string(contract.caseManifest.Classification(hit));
                MethodologicalRole(i)=string( ...
                    contract.caseManifest.MethodologicalRole(hit));
                if MethodologicalRole(i)=="external_test"
                    splitRole(i)="test";
                else
                    splitRole(i)="train";
                end
            end
        end
    end
    splitSeed=repmat(double(cfg.realExtended.splitSeed),n,1);
    registry=table(CaseID,CanonicalCaseID,splitRole, ...
        MethodologicalRole,Classification,DuplicateGroup, ...
        SplitGroup,splitSeed, ...
        'VariableNames',{'CaseID','CanonicalCaseID','split_role', ...
        'MethodologicalRole','Classification','DuplicateGroup', ...
        'SplitGroup','split_seed'});
    registry=sortrows(registry,'CaseID');
end
