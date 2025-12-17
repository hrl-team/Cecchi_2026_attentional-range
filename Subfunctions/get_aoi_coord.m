function [left, middle, right] = get_aoi_coord()

% Screen width = 526 mm
% Screen height = 295 mm
% Stimuli width = 50 mm
% Stimuli height = 50 mm

% Add a margin to account for EyeLink's average accuracy of ~0.5 degrees of visual angle
% https://www.sr-research.com/eye-tracking-blog/background/visual-angle/
% It has also been suggested that margins should be added around AOIs to compensate for inaccuracy
% (Holmqvist & Andersson, 2017; Orquin et al., 2016)

% Measures (in cm)
screenX = 52.6;
screenY = 29.5;
adjacent = 71; % Distance between participant and screen center
stim_size = 5; % Size of stimulus on the screen (height and width)
h_dist_out = 6.2; % Horizontal distance from the edge of the screen to the first stimulus (same on left and right)
h_dist_in = 12.6; % Horizontal distance between stimuli
v_dist = 12.25; % Vertical distance from the edge of the screen to the top of stimuli (same top and bottom)

margin_visual_angle = 1.5; % In degree

% Margin of middle stimuli
middle_stim_angle = atand((stim_size/2) / adjacent); % In degree
middle_margin_angle = margin_visual_angle + middle_stim_angle; % In degree
stim_w_margin = tand(middle_margin_angle) * adjacent; % In cm
x_margin_middle = stim_w_margin - (stim_size/2); % In cm

% X margin of side stimuli
dist_side = [stim_size/2+h_dist_in, stim_size/2+h_dist_in+stim_size]; % Distance from the edge closest (1) / furthest (2) to the centre
for dist = 1:numel(dist_side)
    side_stim_closest_angle = atand(dist_side(dist) / adjacent); % In degree
    side_closest_margin_angle = side_stim_closest_angle - margin_visual_angle; % In degree
    dist_stim_w_margin = tand(side_closest_margin_angle) * adjacent; % In cm
    margin(dist) = dist_side(dist) - dist_stim_w_margin; % In cm
end
x_margin_close_side = margin(1);
x_margin_far_side = margin(2);

y_margin = x_margin_middle; % In cm (identical for all stimuli as they are vertically centred)

%% Normalized coordinates

botY = (v_dist - y_margin) / screenY;
topY = (v_dist + y_margin + stim_size) / screenY;

% Left
leftX = (h_dist_out - x_margin_far_side) / screenX;
rightX = (h_dist_out + stim_size + x_margin_close_side) / screenX;

left.x = [leftX rightX rightX leftX];
left.y = [botY botY topY topY];

% Middle
leftX = (h_dist_out + stim_size + h_dist_in - x_margin_middle) / screenX;
rightX = (h_dist_out + stim_size + h_dist_in + stim_size + x_margin_middle) / screenX;

middle.x = [leftX rightX rightX leftX];
middle.y = [botY botY topY topY];

% Right
leftX = (h_dist_out + stim_size + h_dist_in + stim_size + h_dist_in - x_margin_close_side) / screenX;
rightX = (h_dist_out + stim_size + h_dist_in + stim_size + h_dist_in + stim_size + x_margin_far_side) / screenX;

right.x = [leftX rightX rightX leftX];
right.y = [botY botY topY topY];

end