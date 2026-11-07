function root = active_uqlab_root()
%ACTIVE_UQLAB_ROOT Root folder of the UQLab distribution on the MATLAB path.
%   ROOT = utils.active_uqlab_root() is the distribution root of the uqlab
%   entry point that MATLAB currently resolves (the one utils.activate_uqlab
%   put on the path): <root>/core/uqlab.m. Empty when UQLab is not on the
%   path. Replaces reading the UQLAB_ROOT environment variable back after
%   activation (CLN-007).
%   Side effects: none.

    entry = which('uqlab');
    if isempty(entry)
        root = '';
    else
        root = fileparts(fileparts(entry));
    end
end
