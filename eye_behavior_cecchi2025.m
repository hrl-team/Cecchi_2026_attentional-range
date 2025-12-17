%
% Purpose:      Performs fixation-based behavioral analysis for the study:
%               "Elucidating Attentional Mechanisms Underlying Value 
%               Normalization in Human Reinforcement Learning"
%
% Authors:      Romane Cecchi, Sebastian Gluth, Stefano Palminteri
% Year:         2025
%
% Description:  This script analyzes eye-tracking data to quantify fixation
%               times on stimuli and outcomes during the learning phase of 
%               three reinforcement learning experiments.
%
% Usage:        Adjust the 'init.task' and 'init.analyse' parameters to 
%               select the experiment and the analysis to run.
%
%       - init.task:
%               - 'e1_forced'   : Top-down attention manipulation (Exp. 1)
%               - 'e2_lum_stim' : Stimulus saliency manipulation (Exp. 2)
%               - 'e3_lum_out'  : Outcome saliency manipulation (Exp. 3)
%
%       - init.analyse:
%               1: Compute fixation ratios across contexts and trial types
%
% Notes:        - Set `init.plot = 1` to generate visualizations
%               - Set `init.opt_splitting` to define trial splitting rule
%                 ('value' or 'mergeWNvalue')
%
% -------------------------------------------------------------------------
% Written by Romane Cecchi, 2025

clear
close all hidden
clc

% Settings
init.task = 'e3_lum_out'; % 'e1_forced'|'e2_lum_stim'|'e3_lum_out'
init.analyse = 1;

% Options
init.opt_splitting = 'mergeWNvalue'; % value | mergeWNvalue
init.plot = 1; % Plot figures? -> 1 = yes | 0 = no

% Data path
init.path = '/Users/romane/Documents/Pub_codes/Cecchi_2025_attention_norm_RL/Data';

% -------------------------------------------------------------------------

% Import database tables (Header: 1 line = 1 participant ; Expe: 1 line = 1 trial)
init.db = load(fullfile(init.path, sprintf('%s_data.mat', init.task)), 'header', 'expe');

% Import AOIs coordinates
[init.aoi.left, init.aoi.middle, init.aoi.right] = get_aoi_coord();
init.aoi_names = fieldnames(init.aoi); % Important to keep left - middle - right order as this is the order of the DB arrays

%% Spec

init.phase      = 'learning';
init.fix        = 'all';
init.var_of_int = 'fixation';

%% Analyses

phase_part    = {'stimuli', 'outcomes'}; % stimuli | outcomes

for phase_part_loop = 1:numel(phase_part)

    init.phase_part = phase_part{phase_part_loop}; % stimuli | outcomes

    switch init.analyse
        case 1
            get_fix_time_nary(init); % Divide conditions by ternary/binary trials
    end

end
