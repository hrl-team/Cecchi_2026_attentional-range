%
% Purpose:      Performs behavioral analyses for the study:
%               "Elucidating Attentional Mechanisms Underlying Value 
%               Normalization in Human Reinforcement Learning"
%
% Authors:      Romane Cecchi, Sebastian Gluth, Stefano Palminteri
% Year:         2025
%
% Description:  This script performs behavioral analyses on data collected
%               from three reinforcement learning experiments designed to 
%               investigate the role of visual attention in shaping 
%               subjective value through range normalization. Participants
%               completed a learning phase (with full feedback) and a 
%               transfer phase (no feedback). The experiments manipulated 
%               attention using top-down (Exp. 1) and bottom-up (Exp. 2 & 
%               3) mechanisms while recording eye movements.
%
% Usage:        Adjust the 'opt.task' and 'opt.analyse' parameters to 
%               specify the dataset and the analysis to perform.
%
%       - opt.task:
%               - 'e1_forced'   : Top-down attention manipulation (Exp. 1)
%               - 'e2_lum_stim' : Stimulus saliency manipulation (Exp. 2)
%               - 'e3_lum_out'  : Outcome saliency manipulation (Exp. 3)
%
%       - opt.analyse:
%               1: Correct choice rate during the learning phase (Figure 2a)
%               2: Cumulative choice counts during learning (Figure 2b)
%               3: Correct choice rate during the transfer phase
%               4: Choice rate during the transfer phase (Figure 2c)
%               5: Transfer choice matrix (Supplementary Figure 1)
%
% Dependencies: Requires .mat files containing 'header' and 'expe' tables
%               (one row per participant and one row per trial, respectively).
%
% Notes:        - Set `opt.plot = 1` to enable figure generation
%               - Set `opt.merge_range = 1` to collapse wide/narrow contexts
%
% -------------------------------------------------------------------------
% Written by Romane Cecchi, 2025

clearvars
close all
clc

% Settings
opt.task = 'e3_lum_out'; % 'e1_forced'|'e2_lum_stim'|'e3_lum_out'
opt.analyse = 5;

% Data path
init.path = '/Users/romane/Documents/Pub_codes/Cecchi_2025_attention_norm_RL/Data';

% -------------------------------------------------------------------------

% Merge wide and narrow contexts? -> 1 = yes | 0 = no
switch opt.task
    case {'e1_forced'}
        opt.merge_range = 0;
    case {'e2_lum_stim', 'e3_lum_out'}
        opt.merge_range = 1;
end

opt.plot  = 1; % Plot figures? -> 1 = yes | 0 = no
opt.stats = 1; % Display stats? -> 1 = yes | 0 = no

%% First step: Import database tables
% Header: 1 line = 1 participant
% Expe: 1 line = 1 trial

db = load(fullfile(init.path, sprintf('%s_data.mat', opt.task)), 'header', 'expe');

%% Second step: Analyses

switch opt.analyse

    case 1 % Test the correct choice rate during the LEARNING phase (Fig. 2a)
        correct_choice_rate_learning(db, fileparts(init.path), opt)

    case 2 % Get LEARNING choice count (Fig. 2b)
        choice_count_learning(db, fileparts(init.path), opt);

    case 3 % Test the correct choice rate during the TRANSFER phase
        correct_choice_rate_transfer(db, opt);

    case 4 % Get choice rate during the TRANSFER phase (Fig. 2c)
        choice_rate_transfer(db, fileparts(init.path), opt);

    case 5 % Get choice matrix of the TRANSFER phase (Supp. Fig. 1)
        choice_matrix_transfer(db, fileparts(init.path), opt)

end