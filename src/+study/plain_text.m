function t = plain_text(t)
%PLAIN_TEXT A figure title written for the TeX interpreter, as plain readable text.
%   T = study.plain_text(T) replaces the TeX commands that figure titles use
%   (Greek letters, \pm, \times, relations, ^2) by their Unicode characters
%   and removes grouping braces and font switches, for the index of the
%   analysis README files (study.index_entry).
%   Side effects: none.

    t = char(string(t));
    symbols = { ...
        '\alpha', char(945); '\beta', char(946); '\gamma', char(947); ...
        '\Delta', char(916); '\delta', char(948); '\epsilon', char(949); ...
        '\theta', char(952); '\lambda', char(955); '\mu', char(956); ...
        '\rho', char(961); '\sigma', char(963); '\tau', char(964); ...
        '\phi', char(966); '\chi', char(967); '\omega', char(969); ...
        '\pm', char(177); '\times', char(215); '\cdot', char(183); ...
        '\leq', char(8804); '\geq', char(8805); '\le', char(8804); ...
        '\ge', char(8805); '\approx', char(8776); '\neq', char(8800); ...
        '\infty', char(8734); '\rightarrow', char(8594); '\to', char(8594)};
    % Longest command first, so that \leq is not read as \le followed by q.
    [~, order] = sort(cellfun(@numel, symbols(:, 1)), 'descend');
    for i = order'
        t = regexprep(t, [regexptranslate('escape', symbols{i, 1}) '(?![A-Za-z])'], symbols{i, 2});
    end
    t = regexprep(t, '\\(it|rm|bf|sf|tt)(?![A-Za-z])\s*', '');
    t = regexprep(t, '\^\{?2\}?', char(178));
    t = regexprep(t, '\^\{?3\}?', char(179));
    t = regexprep(t, '\^\{?-1\}?', [char(8315) char(185)]);
    t = strrep(strrep(t, '{', ''), '}', '');
    t = strrep(t, '\_', '_');
    t = regexprep(t, '\s+', ' ');
end
