%% Fitting for a three-armed bandit
% ---------------------------------
% Romane Cecchi, 2023
%
% TASK:
% 2x3 design, 45 trials per condition
% cond 1 = Wide 100% ternary/max (Wt100/Wh100)
% cond 2 = Wide 50% binary/mid (Wb50/Wm50)
% cond 3 = Narrow 100% ternary/max (Nt100/Nh100)
% cond 4 = Narrow 50% binary/mid (Nb50/Nm50)

clearvars
close all hidden
clear all

%% MODELS

% ABSOLUTE
% 1: Q-LEARNING 1 alpha (= no normalization = Qvalue from 0 to 100)

% WEIGHTED (NON-LINEAR) RANGE NORMALIZATION
% 2: RANGE 1 alpha 2 omega -> 1 omega by attentional condition (100/50)

% ATTENTIONAL RANGE NORMALIZATION
% 3: EYE RANGE 1 alpha + 1 phi (weighted sum of stim and out fix)
% 4: EYE RANGE 1 alpha (stim fix only)
% 5: EYE RANGE 1 alpha (out fix only)

% FIXATION-ONLY
% 6: EYE only 1 alpha + 1 phi (weighted sum of stim and out fix)
% 7: EYE only 1 alpha (stim fix only)
% 8: EYE only 1 alpha (out fix only)

% ATTENTION AFTER RANGE NORMALIZATION
% 9:  RANGE EYE 1 alpha + 1 phi (weighted sum of stim and out fix)
% 10: RANGE EYE 1 alpha (stim fix only)
% 11: RANGE EYE 1 alpha (out fix only)

% POWER-LAW COMPRESSION
% 12: Power-law compression

% Ε-GREEDY
% 13: RANGE 1 alpha 1 epsilon [Range + Argmax + Epsilon-greedy in transfer]

% PERSEVERATION
% 14: Choice perseveration (Katahira)

% INCREMENTAL WINDOW ATTENTIONAL RANGE
% 15: run model_fitting_incremental_window.m

% DISCRETE WINDOW ATTENTIONAL RANGE
% 16: run model_fitting_discrete_window.m

%% Options

opt.task = 'e3_lum_out'; % 'e1_forced'|'e2_lum_stim'|'e3_lum_out'
opt.whichmodel = 1:14; % Main model space: 1:5

opt.phase_fit = 'both'; % 'learning'|'transfer'|'both'

% Data path
init.path = '/Users/romane/Documents/Pub_codes/Cecchi_2025_attention_norm_RL/Data';

%%
opt.modeling_step = 'fitting';

params = def_models_param(1); % Only to retrieve param names
opt.param_name = params.names;
opt.param_nb = numel(opt.param_name);

%% Import database tables
% Header: 1 line = 1 participant
% Expe: 1 line = 1 trial

db = load(fullfile(init.path, sprintf('%s_data.mat', opt.task)), 'header', 'expe');

%% Import eye-tracking data

load(fullfile(init.path, 'Eye_data', opt.task, sprintf('fix_ratio_learning_stimuli_%s.mat', opt.task))); % Stimuli data
eye_data_stim = out;

load(fullfile(init.path, 'Eye_data', opt.task, sprintf('fix_ratio_learning_outcomes_%s.mat', opt.task))); % Outcomes data
eye_data_out = out;

%% Start

w = waitbar(0, 'Starting...');

% Initialization
parameters = NaN(height(db.header), opt.param_nb, max(opt.whichmodel)); % Nsub * Nparam * Nmodel
ll = NaN(height(db.header), max(opt.whichmodel)); % Nsub * Nmodel

for sub = 1:height(db.header) % Loop through participants

    waitbar(sub/height(db.header), w, sprintf('Processing of participant %d / %d', sub, height(db.header)));
    data = format_sub_data_for_fitting(opt, db, sub, eye_data_stim, eye_data_out);

    %% OPTIMIZATION

    % "fmincon" parameters
    fmin_opt = optimset('Algorithm', 'interior-point', 'Display', 'off', 'MaxIter', 10000, 'MaxFunEval', 10000);

    for model_idx = opt.whichmodel % Loop through models

        model_param = def_models_param(model_idx); % Get model parameters

        model_info.idx = model_idx;
        model_info.param = model_param;

        if sub == height(db.header) % Last subject
            fit.in.model_param(model_idx) = model_param; % For backup
        end

        [parameters(sub,:,model_idx), ll(sub, model_idx)] = fmincon(@(params) ...
            threeArmedBandit_models_run_cecchi2025(params, data, model_info, opt.modeling_step, opt.phase_fit),...
            model_param.initial_point, [],[],[],[], model_param.lower_bounds, model_param.upper_bounds, [], fmin_opt);

        %% BIC computation

        if sub == height(db.header) % Last subject

            switch opt.phase_fit
                case 'learning'
                    total_trial = numel(data.learning.cond_idx);
                case 'transfer'
                    total_trial = numel(data.transfer.choice_idx);
                case 'both'
                    total_trial = numel(data.learning.cond_idx) + numel(data.transfer.choice_idx);
            end
            fit.out.bic(:,model_idx) = -2 * -ll(:,model_idx) + model_param.nfpm * log(total_trial);

        end

    end % End of the loop through models

    % For backup
    fit.in.data(sub) = data;

end % End of the loop through subjects

delete(w);

%% Display data

for model_idx = opt.whichmodel % Loop through models

    % Model parameters
    fprintf('\n----------- Model %d -----------\n\n', model_idx)
    disp(array2table(mean(parameters(:,:,model_idx)), 'VariableNames', params.names))

    % BIC
    fprintf(['\n-------------------------------\n' ...
        'BIC Model %d : %.0f ± %.0f\n' ...
        '-------------------------------\n\n'], model_idx, mean(fit.out.bic(:,model_idx)), std(fit.out.bic(:,model_idx)))
end

%% SAVE DATA

fit.in.opt = opt;
fit.in.fmin_opt = fmin_opt;

fit.out.params = parameters;
fit.out.ll = ll;

save(fullfile(fileparts(init.path), 'Modelling_results', sprintf('fitting_%s_phase_cecchi2025_%s.mat', opt.phase_fit, opt.task)), 'fit');

%% Model comparison (VBA toolbox)

if numel(opt.whichmodel) > 1

    vba_opt.verbose = 0;

    % % VBA_groupBMC(-fit.out.ll')
    [posterior,out] = VBA_groupBMC((-fit.out.bic(:,opt.whichmodel)/2)', vba_opt); % Why -1/2 * BIC : https://statswithr.github.io/book/bayesian-model-choice.html

    % Save figure
    fig_name = fullfile(fileparts(init.path), 'Figures', 'Fitting', sprintf('%s_models_%s_comparison_%s_fit', opt.task, strjoin(string(opt.whichmodel), '_'), opt.phase_fit));
    savefig(fig_name)
    close

end