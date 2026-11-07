function restore = preserve_graphics_defaults()
%PRESERVE_GRAPHICS_DEFAULTS Restore the graphics defaults of the MATLAB root when done (CLN-058).
%   RESTORE = plotting.preserve_graphics_defaults() records the current
%   defaults of the graphics root (get(groot,'default')) and returns an
%   onCleanup object: when RESTORE is cleared (for example when the calling
%   function returns or fails), every default set in between (plotting.style,
%   invisible figures) is removed and the recorded ones are set again.
%   Side effects: none until RESTORE is cleared.
    saved = get(groot, 'default');
    restore = onCleanup(@() restore_defaults(saved));
end

function restore_defaults(saved)
    current = get(groot, 'default');
    names = fieldnames(current);
    for i = 1:numel(names)
        if ~isfield(saved, names{i})
            set(groot, names{i}, 'remove');
        end
    end
    names = fieldnames(saved);
    for i = 1:numel(names)
        set(groot, names{i}, saved.(names{i}));
    end
end
