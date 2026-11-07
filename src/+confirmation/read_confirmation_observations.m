function observed = read_confirmation_observations(design, pathValue, outputNames, requiredOutputs)
%READ_CONFIRMATION_OBSERVATIONS The accepted observations of the design, one row per design row.
%   OBSERVED = confirmation.read_confirmation_observations(DESIGN, PATH,
%   OUTPUTNAMES, REQUIREDOUTPUTS) reads the accepted observation table PATH
%   (confirmation.import_confirmation_observations; the thesis table is
%   data/confirmation/confirmation_observations.csv) and joins every row to
%   the row of the design DESIGN (confirmation.confirmation_design) with
%   exactly the same COMSOL inputs (confirmation.join_by_values): one row
%   per design row, none left out, none repeated. Every accepted design row
%   (column Accepted; a table without it accepts every row) needs the
%   closing pressures REQUIREDOUTPUTS (the observation design's; default:
%   all of OUTPUTNAMES, the route's outputs, mbar) finite and positive; a
%   row the reviewer excluded keeps its QC-valid pressures and NaN for the
%   others, and its ExclusionReason: its cells are unavailable.
%   OBSERVED: the table in design order, with the design's DesignIndex,
%   MaterialCaseID and Protocol, the pressures, Accepted (logical),
%   ExclusionReason and the table's other columns (the solve statuses and
%   the COMSOL model).
%   Side effects: none.

    assert(isfile(pathValue), 'confirmation:read_confirmation_observations:Missing', ...
        ['No accepted confirmation observations: %s is missing. Import the reviewed COMSOL ' ...
         'observations with the step ''import_observations'' first.'], pathValue);
    inputs = confirmation.comsol_inputs();
    outputNames = reshape(cellstr(string(outputNames)), 1, []);
    if nargin < 4 || isempty(requiredOutputs), requiredOutputs = outputNames; end
    requiredOutputs = reshape(cellstr(string(requiredOutputs)), 1, []);
    names = [inputs outputNames];
    T = confirmation.read_exact_table(pathValue, [names {'Accepted'}]);
    missing = names(~ismember(names, T.Properties.VariableNames));
    assert(isempty(missing), 'confirmation:read_confirmation_observations:Columns', ...
        'The observation table %s lacks the columns: %s.', pathValue, strjoin(missing, ', '));
    if ~ismember('Accepted', T.Properties.VariableNames)
        T.Accepted = ones(height(T), 1);
    end
    if ~ismember('ExclusionReason', T.Properties.VariableNames)
        T.ExclusionReason = strings(height(T), 1);
    end
    assert(all(ismember(T.Accepted, [0 1])), 'confirmation:read_confirmation_observations:Accepted', ...
        'The column Accepted of %s must be 0 or 1 in every row.', pathValue);
    T.Accepted = logical(T.Accepted);
    rows = design.rows;
    at = confirmation.join_by_values(rows, T, inputs, ...
        "case" + string(rows.MaterialCaseID) + "_" + rows.Protocol, pathValue);
    Y = T{:, requiredOutputs};
    bad = find(T.Accepted & ~all(isfinite(Y) & Y > 0, 2));
    assert(isempty(bad), 'confirmation:read_confirmation_observations:Pressures', ...
        'Accepted lines %s of %s lack finite, positive closing pressures %s.', ...
        strjoin(string(bad + 1), ', '), pathValue, strjoin(requiredOutputs, ', '));
    silent = find(~T.Accepted & strlength(strtrim(T.ExclusionReason)) == 0);
    assert(isempty(silent), 'confirmation:read_confirmation_observations:Exclusion', ...
        'Lines %s of %s are not accepted but give no ExclusionReason.', ...
        strjoin(string(silent + 1), ', '), pathValue);
    % The rows of the table in design order.
    order = zeros(height(rows), 1);
    order(at) = 1:height(T);
    T = T(order, :);
    other = setdiff(T.Properties.VariableNames, [{'MaterialCaseID', 'Protocol'} names], 'stable');
    observed = [rows(:, {'DesignIndex', 'MaterialCaseID', 'Protocol'}), T(:, [outputNames other])];
end
