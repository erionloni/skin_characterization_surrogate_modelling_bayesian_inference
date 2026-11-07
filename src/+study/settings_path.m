function p = settings_path(s, p)
%SETTINGS_PATH A path of the settings as an absolute path.
%   P = study.settings_path(S, P) returns P when it is absolute and
%   otherwise P below the repository folder (S.paths.repository): paths in
%   study_settings.m are relative to the repository unless absolute.
%   Side effects: none.
    p = char(string(p));
    if isempty(p), return; end
    if ~(startsWith(p, filesep) || ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\'))
        p = fullfile(s.paths.repository, strrep(p, '/', filesep));
    end
end
