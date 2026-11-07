function removed = remove_stale_images(before)
%REMOVE_STALE_IMAGES Delete a finished family's images that it did not write again (CLN-056).
%   REMOVED = plotting.remove_stale_images(BEFORE) takes the listing of
%   plotting.family_images made before the family rendered. Every image the
%   family wrote again was replaced atomically (plotting.export_saved_figure)
%   and has a new modification time; an image whose time is unchanged was not
%   produced by this pass (for example a figure the family no longer draws)
%   and is deleted, so it cannot enter a receipt. REMOVED lists the deleted
%   paths. Call it only after the family completed.
%   Side effects: deletes files.
    removed = {};
    for i = 1:numel(before)
        d = dir(before(i).path);
        if ~isempty(d) && d.datenum == before(i).datenum
            delete(before(i).path);
            removed{end+1} = before(i).path; %#ok<AGROW>
        end
    end
end
