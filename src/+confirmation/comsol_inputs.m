function names = comsol_inputs()
%COMSOL_INPUTS The inputs of a confirmation COMSOL solve, by which its observations join the design.
%   NAMES = confirmation.comsol_inputs() returns the columns that give the
%   material (m3_f_RD, m3_e_RD, k0_RD in mm^4/(N s), Thickness_RD in mm) and
%   the protocol (SignedRate_kPa_s, Hold_s, Pause_s) of a solve, exactly as
%   COMSOL received them: the run list of the design
%   (confirmation.confirmation_design), the reviewed COMSOL export and the
%   accepted observations hold them as exact doubles, and a row belongs to
%   the design row with the same values (no ID).
%   Side effects: none.
    names = {'m3_f_RD', 'm3_e_RD', 'k0_RD', 'Thickness_RD', 'SignedRate_kPa_s', 'Hold_s', 'Pause_s'};
end
