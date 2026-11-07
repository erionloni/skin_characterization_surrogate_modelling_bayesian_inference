function [membership,summary] = reconstruction_matched_cohorts( ...
        availability,expectedCaseIDs,fittingDesigns,scenarios)
%RECONSTRUCTION_MATCHED_COHORTS Exact six-design reconstruction intersections.
%   Missing and invalid cells remain explicit.  A CaseID is included for a
%   scenario only when every requested fitting design has one certified,
%   valid reconstruction record.
%   [MEMBERSHIP, SUMMARY] = recovery.reconstruction_matched_cohorts(
%   AVAILABILITY, EXPECTEDCASEIDS, FITTINGDESIGNS, SCENARIOS) returns, per
%   scenario and case, whether it is in the matched cohort, and the counts.
%   Side effects: none.

    required={'Scenario','CaseID','FittingDesign', ...
        'CertifiedPosteriorAvailable','ReconstructionValid','ExclusionReason'};
    assert(istable(availability)&& ...
        all(ismember(required,availability.Properties.VariableNames)), ...
        'recovery:reconstruction_matched_cohorts:AvailabilitySchema', ...
        'Availability does not satisfy the matched-cohort contract.');
    expectedCaseIDs=reshape(double(expectedCaseIDs),1,[]);
    fittingDesigns=reshape(string(fittingDesigns),1,[]);
    scenarios=reshape(string(scenarios),1,[]);
    assert(~isempty(expectedCaseIDs)&& ...
        numel(unique(expectedCaseIDs))==numel(expectedCaseIDs)&& ...
        numel(fittingDesigns)==6&&numel(unique(fittingDesigns))==6&& ...
        numel(scenarios)==2&&numel(unique(scenarios))==2, ...
        'recovery:reconstruction_matched_cohorts:Axes', ...
        'Expected a configured unique cohort, six designs, and two scenarios.');
    availability.Scenario=string(availability.Scenario);
    availability.FittingDesign=string(availability.FittingDesign);
    availability.CaseID=double(availability.CaseID);
    availability.CertifiedPosteriorAvailable=to_logical( ...
        availability.CertifiedPosteriorAvailable);
    availability.ReconstructionValid=to_logical( ...
        availability.ReconstructionValid);
    availability.ExclusionReason=string(availability.ExclusionReason);

    expectedRows=numel(expectedCaseIDs)*numel(fittingDesigns)*numel(scenarios);
    assert(height(availability)==expectedRows, ...
        'recovery:reconstruction_matched_cohorts:RowCount', ...
        'Availability must contain one row for every expected cell.');
    n=numel(expectedCaseIDs)*numel(scenarios);
    scenarioColumn=strings(n,1);caseColumn=nan(n,1);expected=true(n,1);
    included=false(n,1);reason=strings(n,1);cursor=0;
    summaryParts=cell(numel(scenarios),1);
    for s=1:numel(scenarios)
        scenarioIncluded=false(numel(expectedCaseIDs),1);
        scenarioReasons=strings(numel(expectedCaseIDs),1);
        for c=1:numel(expectedCaseIDs)
            cursor=cursor+1;scenarioColumn(cursor)=scenarios(s);
            caseColumn(cursor)=expectedCaseIDs(c);
            rows=availability.Scenario==scenarios(s)& ...
                availability.CaseID==expectedCaseIDs(c);
            one=availability(rows,:);
            assert(height(one)==numel(fittingDesigns)&& ...
                all(ismember(fittingDesigns,one.FittingDesign))&& ...
                numel(unique(one.FittingDesign))==numel(fittingDesigns), ...
                'recovery:reconstruction_matched_cohorts:CellBinding', ...
                'Availability must bind each scenario/case/design exactly once.');
            valid=one.CertifiedPosteriorAvailable&one.ReconstructionValid;
            if ismember('ProviderAvailable',one.Properties.VariableNames)
                valid=one.ProviderAvailable&one.ReconstructionValid;
            end
            scenarioIncluded(c)=all(valid);included(cursor)=all(valid);
            if ~all(valid)
                missing=one(~valid,:);pieces=strings(height(missing),1);
                for k=1:height(missing)
                    why=missing.ExclusionReason(k);
                    if strlength(why)==0
                        if ~missing.CertifiedPosteriorAvailable(k)
                            why="certified_posterior_unavailable";
                        else
                            why="reconstruction_invalid";
                        end
                    end
                    pieces(k)=missing.FittingDesign(k)+":"+why;
                end
                scenarioReasons(c)=strjoin(pieces,';');
                reason(cursor)=scenarioReasons(c);
            end
        end
        includedIDs=expectedCaseIDs(scenarioIncluded);
        excludedIDs=expectedCaseIDs(~scenarioIncluded);
        summaryParts{s}=table(scenarios(s),numel(expectedCaseIDs), ...
            numel(includedIDs),numel(excludedIDs), ...
            strjoin(string(includedIDs),','),strjoin(string(excludedIDs),','), ...
            strjoin(scenarioReasons(~scenarioIncluded),'|'), ...
            'VariableNames',{'Scenario','ExpectedCaseCount', ...
            'IncludedCaseCount','ExcludedCaseCount','IncludedCaseIDs', ...
            'ExcludedCaseIDs','ExclusionReasons'});
    end
    membership=table(scenarioColumn,caseColumn,expected,included,reason, ...
        'VariableNames',{'Scenario','CaseID','Expected', ...
        'IncludedInMatchedCohort','ExclusionReason'});
    summary=vertcat(summaryParts{:});
end

function value=to_logical(input)
    if islogical(input),value=input;return;end
    if isnumeric(input),value=input~=0;return;end
    value=ismember(lower(string(input)),["true" "1"]);
end
