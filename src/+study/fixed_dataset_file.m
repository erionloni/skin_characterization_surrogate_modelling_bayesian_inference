function f = fixed_dataset_file(s)
%FIXED_DATASET_FILE The fixed-route dataset CSV of the settings (A.1).
%   F = study.fixed_dataset_file(S) returns the file of the setting
%   fixed.dataset.file (a call's 'FixedDataFile' replaces it) as an absolute
%   path. Errors when it does not exist.
%   Side effects: none.
    f = study.settings_path(s, s.fixed.dataset.file);
    assert(isfile(f), 'study:FixedDatasetMissing', ...
        ['The fixed-route dataset was not found: %s\nRestore data/fixed/ from the ' ...
         'repository, or set fixed.dataset.file in study_settings.m.'], f);
end
