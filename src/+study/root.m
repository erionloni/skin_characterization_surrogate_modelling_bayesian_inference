function r = root()
%ROOT Absolute path of the repository folder (the folder of study_settings.m).
%   R = study.root() returns it without a trailing separator.
%   Side effects: none.
    r = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
