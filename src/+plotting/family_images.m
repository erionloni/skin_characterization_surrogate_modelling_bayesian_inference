function before = family_images(root, names)
%FAMILY_IMAGES The image files of one renderer family, before it renders (CLN-056).
%   BEFORE = plotting.family_images(ROOT) lists every PNG and PDF below ROOT,
%   a folder that holds one renderer family only. BEFORE =
%   plotting.family_images(ROOT, NAMES) lists only ROOT/<NAMES>.png and .pdf,
%   for a family that shares its folder with others. Each entry records the
%   file's modification time; plotting.remove_stale_images(BEFORE), called
%   when the family has finished, deletes the images this pass did not write
%   again. A family interrupted part-way therefore keeps its previous images.
%   Side effects: none.
    before = struct('path', {}, 'datenum', {});
    if ~isfolder(root), return; end
    if nargin < 2
        files = [dir(fullfile(root, '**', '*.png')); dir(fullfile(root, '**', '*.pdf'))];
    else
        files = struct('folder', {}, 'name', {}, 'datenum', {});
        for i = 1:numel(names)
            for extension = {'.png', '.pdf'}
                d = dir(fullfile(root, [names{i} extension{1}]));
                if ~isempty(d), files(end+1) = struct('folder', d.folder, 'name', d.name, ...
                        'datenum', d.datenum); end %#ok<AGROW>
            end
        end
    end
    for i = 1:numel(files)
        before(end+1) = struct('path', fullfile(files(i).folder, files(i).name), ...
            'datenum', files(i).datenum); %#ok<AGROW>
    end
end
