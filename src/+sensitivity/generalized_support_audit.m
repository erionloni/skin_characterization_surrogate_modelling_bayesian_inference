function audit = generalized_support_audit(queryX,trainX,plannedX,plannedClass,bounds,varargin)
%GENERALIZED_SUPPORT_AUDIT Classify full-box points against selected-snapshot support.
%   The guard is descriptive: distance to selected training inputs is combined
%   with the outcome class of the nearest planned CaseID. It does not convert a
%   feasibility-selected cohort into an independent full-box design.
%   AUDIT = sensitivity.generalized_support_audit(QUERYX, TRAINX, PLANNEDX,
%   PLANNEDCLASS, BOUNDS, ...) returns one row per query point: its
%   normalized distance to the nearest training input and to the nearest
%   planned case, that case's row and class, and the support class.
%   Side effects: none.

    options=struct('WellThreshold',NaN,'WeakThreshold',NaN,'ChunkSize',2000);
    options=parse_options(options,varargin{:});
    M=size(bounds,1);
    assert(isnumeric(queryX)&&size(queryX,2)==M&&all(isfinite(queryX),'all')&& ...
        isnumeric(trainX)&&size(trainX,2)==M&&~isempty(trainX)&& ...
        isnumeric(plannedX)&&size(plannedX,2)==M&&~isempty(plannedX), ...
        'sensitivity:generalized_support_audit:Shape', ...
        'Query, training, and planned inputs must share the configured dimension.');
    plannedClass=string(plannedClass(:));
    assert(numel(plannedClass)==size(plannedX,1), ...
        'sensitivity:generalized_support_audit:PlannedClass', ...
        'One planned support/outcome class is required per planned point.');

    lo=bounds(:,1).';span=(bounds(:,2)-bounds(:,1)).';
    queryU=(queryX-lo)./span;
    trainU=(trainX-lo)./span;
    plannedU=(plannedX-lo)./span;
    assert(all(queryU>=-1e-12 & queryU<=1+1e-12,'all'), ...
        'sensitivity:generalized_support_audit:OutsideBox', ...
        'Sensitivity points must remain inside the intended campaign box.');

    if ~(isfinite(options.WellThreshold)&&isfinite(options.WeakThreshold))
        leaveOne=nearest_distance(trainU,trainU,options.ChunkSize,true);
        threshold=utils.weighted_quantile(leaveOne,[0.75 0.95]);
        options.WellThreshold=threshold(1);
        options.WeakThreshold=threshold(2);
    end
    assert(options.WellThreshold>0 && ...
        options.WeakThreshold>=options.WellThreshold, ...
        'sensitivity:generalized_support_audit:Thresholds', ...
        'Support thresholds must be positive and ordered.');

    [distanceTrain,~]=nearest_distance(queryU,trainU,options.ChunkSize,false);
    [distancePlanned,nearestPlanned]=nearest_distance( ...
        queryU,plannedU,options.ChunkSize,false);
    baseClass=repmat("extrapolative",size(queryX,1),1);
    baseClass(distanceTrain<=options.WeakThreshold)="weakly_supported";
    baseClass(distanceTrain<=options.WellThreshold)="well_supported";

    nearestClass=plannedClass(nearestPlanned);
    supportClass=baseClass;
    noncomplete=contains(nearestClass,"known_noncomplete") | ...
        contains(nearestClass,"inside_known_noncomplete");
    unresolved=contains(nearestClass,"missing") | contains(nearestClass,"unresolved");
    supportClass(noncomplete)="inside_known_noncomplete_region";
    supportClass(unresolved)="unresolved_due_to_missing_outcome";

    categories=["well_supported";"weakly_supported";"extrapolative"; ...
        "inside_known_noncomplete_region";"unresolved_due_to_missing_outcome"];
    count=zeros(numel(categories),1);fraction=count;
    for i=1:numel(categories)
        count(i)=sum(supportClass==categories(i));
        fraction(i)=count(i)/numel(supportClass);
    end
    audit=struct( ...
        'schema_version','real_extended_stage3_support_audit_v1', ...
        'guard_definition','normalized_7d_nearest_training_plus_nearest_planned_outcome_v1', ...
        'query_count',size(queryX,1), ...
        'well_supported_threshold',options.WellThreshold, ...
        'weakly_supported_threshold',options.WeakThreshold, ...
        'category_summary',table(categories,count,fraction, ...
            'VariableNames',{'support_class','count','fraction'}), ...
        'point_table',table((1:size(queryX,1)).',distanceTrain,distancePlanned, ...
            nearestPlanned,nearestClass,baseClass,supportClass, ...
            'VariableNames',{'point_index','nearest_training_distance', ...
            'nearest_planned_distance','nearest_planned_row', ...
            'nearest_planned_class','distance_only_class','support_class'}));
end

function [d,index]=nearest_distance(A,B,chunkSize,excludeDiagonal)
    n=size(A,1);d=nan(n,1);index=zeros(n,1);
    b2=sum(B.^2,2).';
    for first=1:chunkSize:n
        last=min(first+chunkSize-1,n);
        Q=A(first:last,:);
        squared=max(sum(Q.^2,2)+b2-2*(Q*B.'),0);
        if excludeDiagonal && size(A,1)==size(B,1)
            rows=(first:last).';
            squared(sub2ind(size(squared),(1:numel(rows)).',rows))=inf;
        end
        [best,loc]=min(squared,[],2);
        d(first:last)=sqrt(best);
        index(first:last)=loc;
    end
end

function options=parse_options(options,varargin)
    assert(mod(numel(varargin),2)==0, ...
        'sensitivity:generalized_support_audit:Options','Options must be name/value pairs.');
    names=fieldnames(options);
    for i=1:2:numel(varargin)
        hit=find(strcmpi(string(varargin{i}),string(names)),1);
        assert(~isempty(hit),'sensitivity:generalized_support_audit:UnknownOption', ...
            'Unknown option %s.',string(varargin{i}));
        options.(names{hit})=varargin{i+1};
    end
end
