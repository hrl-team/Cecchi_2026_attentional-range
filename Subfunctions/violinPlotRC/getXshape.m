function X = getXshape(xi, fdensity, Y, pos, opt)

% Get the x-values for displaying inside the shape of the violin
xShapeLim = interp1(xi, fdensity, Y);
xpt = [zeros(1, numel(Y)) fliplr(-xShapeLim)];
X = xpt + pos; % Default : left

if isfield(opt, 'violinSpace')
    if ismember(opt.violinSpace, 'right')
        X = -xpt + pos;
    elseif ismember(opt.violinSpace, 'full')
        X = [-xShapeLim fliplr(xShapeLim)] + pos;
    else
    end
end

end