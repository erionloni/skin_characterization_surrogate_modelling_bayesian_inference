function p = artifact_source(s, a)
%ARTIFACT_SOURCE Where a step reads an artifact that this run did not write.
%   P = study.artifact_source(S, A) returns, for the artifact A
%   (study.artifacts) and the resolved settings S, its shipped copy
%   thesis_results/<A.path> (S.paths.results), or, for an artifact that a
%   setting names (A.setting, e.g. generalized.confirmation.observations),
%   that setting's file (study.settings_path).
%   Side effects: none.
    if isempty(a.setting)
        p = fullfile(s.paths.results, strrep(a.path, '/', filesep));
        return;
    end
    value = s;
    for part = strsplit(a.setting, '.')
        value = value.(part{1});
    end
    p = study.settings_path(s, value);
end
