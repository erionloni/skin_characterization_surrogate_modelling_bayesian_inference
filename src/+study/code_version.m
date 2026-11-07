function c = code_version(repository)
%CODE_VERSION The commit of the code, and whether code or configuration differ from it.
%   C = study.code_version(REPOSITORY) returns a struct with fields
%   repository, git_commit (empty when git is unavailable) and git_dirty
%   (true when src/, config/ or an entry-point file differs from the commit,
%   untracked files included; empty when git is unavailable). Data and
%   results are not part of the check, so a run that writes into
%   thesis_results/ does not mark its own code as modified.
%   Recorded in the run record (study.run_record).
%   Side effects: runs git (read-only).

    c = struct('repository', repository, 'git_commit', '', 'git_dirty', []);
    [status, out] = system(sprintf('git -C "%s" rev-parse HEAD', repository));
    if status == 0, c.git_commit = strtrim(out); end
    [status, out] = system(sprintf(['git -C "%s" status --porcelain ' ...
        '--untracked-files=all -- src config ":(glob)*.m"'], repository));
    if status == 0, c.git_dirty = ~isempty(strtrim(out)); end
end
