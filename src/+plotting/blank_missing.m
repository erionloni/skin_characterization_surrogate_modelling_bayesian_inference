function blank_missing(image)
%BLANK_MISSING Show the missing values of a heatmap in grey, not as a colour of the scale.
%   plotting.blank_missing(IMAGE) makes the cells of the image IMAGE (the
%   handle imagesc returns) whose value is NaN transparent over a light grey
%   axes background. An unavailable cell has no value and nothing is filled
%   in; without this, MATLAB draws NaN in the lowest
%   colour of the colormap, which reads as the smallest value.
%   Side effects: changes IMAGE and its axes.
    set(image, 'AlphaData', ~isnan(double(image.CData)));
    set(ancestor(image, 'axes'), 'Color', [0.85 0.85 0.85]);
end
