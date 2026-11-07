function [notes, cellNote] = diagnostic_notes(rhat, tailESS, degenerateRhat, steps, parameters)
%DIAGNOSTIC_NOTES Health notes for undefined or degenerate warning diagnostics of replicate pairs.
%   NOTES = study.diagnostic_notes(RHAT, TAILESS, DEGENERATERHAT) returns,
%   for each row of a pair-diagnostics table (one completed replicate pair
%   and parameter), a note, "" when there is none: "R-hat undefined" when
%   the ensemble-time R-hat is NaN, "R-hat degenerate" when it is at least
%   DEGENERATERHAT (settings A.6), "tail ESS 0" when the tail ESS is 0;
%   several are joined by "; ". These diagnostics are warnings that never
%   gate certification: a note describes them, the diagnostic figures leave
%   such values out, and no status changes.
%   [NOTES, CELLNOTE] = study.diagnostic_notes(..., STEPS, PARAMETERS) also
%   summarizes the rows of ONE cell (their step counts and parameters) for
%   its row of the status table: per kind and step count the parameters,
%   e.g. "R-hat undefined at 2000 steps (m3_f_RD, m3_e_RD)"; "" when no row
%   has a note.
%   Side effects: none.

    rhat = double(rhat(:)); tailESS = double(tailESS(:));
    undefined = isnan(rhat);
    degenerate = ~undefined & rhat >= degenerateRhat;
    zeroTail = tailESS == 0;
    notes = strings(numel(rhat), 1);
    for i = 1:numel(rhat)
        parts = strings(1, 0);
        if undefined(i), parts(end+1) = "R-hat undefined"; end %#ok<AGROW>
        if degenerate(i), parts(end+1) = "R-hat degenerate"; end %#ok<AGROW>
        if zeroTail(i), parts(end+1) = "tail ESS 0"; end %#ok<AGROW>
        notes(i) = strjoin(parts, "; ");
    end
    cellNote = "";
    if nargout < 2, return; end
    steps = double(steps(:)); parameters = string(parameters(:));
    kinds = {"R-hat undefined", undefined; "R-hat degenerate", degenerate; "tail ESS 0", zeroTail};
    parts = strings(1, 0);
    for k = 1:size(kinds, 1)
        for level = reshape(unique(steps(kinds{k, 2})), 1, [])
            which = kinds{k, 2} & steps == level;
            parts(end+1) = sprintf('%s at %d steps (%s)', kinds{k, 1}, level, ...
                strjoin(unique(parameters(which), 'stable'), ', ')); %#ok<AGROW>
        end
    end
    cellNote = strjoin(parts, "; ");
end
