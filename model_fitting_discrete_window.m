%% Fitting for a three-armed bandit
% ---------------------------------
% Romane Cecchi, 2025
%
% TASK:
% 2x3 design, 45 trials per condition
% cond 1 = Wide 100% ternary/max (Wt100/Wh100)
% cond 2 = Wide 50% binary/mid (Wb50/Wm50)
% cond 3 = Narrow 100% ternary/max (Nt100/Nh100)
% cond 4 = Narrow 50% binary/mid (Nb50/Nm50)

clearvars
close all hidden

%% Options

% MODELS:
% 16: EYE RANGE 1 alpha (discrete time window: Supplementary fig. 8)

opt.task = 'e1_forced'; % 'e1_forced'|'e2_lum_stim'|'e3_lum_out'

% Data path
init.path = '/Users/romane/Documents/Pub_codes/Cecchi_2025_attention_norm_RL/Data';

%%

opt.whichmodel = 16;
opt.phase_fit = 'both'; % 'learning'|'transfer'|'both'
opt.modeling_step = 'fitting';
opt.time_type = 'prct';
opt.times = -100:10:100; % -100:10:100; % In percent

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
parameters = cell(1, numel(opt.times)-1); % each cell = Nsub * Nparam
ll = cell(1, numel(opt.times)-1); % NtimeStim * NtimeOut -> each cell = Nsub

for sub = 1:height(db.header) % Loop through participants

    clearvars data
    waitbar(sub/height(db.header), w, sprintf('Processing of participant %d / %d', sub, height(db.header)));

    data = format_sub_data_for_fitting(opt, db, sub, eye_data_stim, eye_data_out);
    data.time = opt.time_type;

    %% OPTIMIZATION

    % "fmincon" parameters
    fmin_opt = optimset('Algorithm', 'interior-point', 'Display', 'off', 'MaxIter', 10000, 'MaxFunEval', 10000);

    model_idx = opt.whichmodel;
    model_param = def_models_param(model_idx);

    model_info.idx = model_idx;
    model_info.param = model_param;

    for nTime = 1:numel(opt.times) - 1

        waitbar(sub/height(db.header), w, sprintf('Processing of participant %d / %d, iteration %g / %g', sub, height(db.header), nTime, numel(opt.times)-1));

        if opt.times(nTime) < 0

            data.fixTimeStim = 100 + [opt.times(nTime) opt.times(nTime+1)];
            data.fixTimeOut = 0;

        elseif opt.times(nTime) >= 0

            data.fixTimeStim = 0;
            data.fixTimeOut = [opt.times(nTime) opt.times(nTime+1)];
        end

        % For backup
        fit.in.data(sub) = data;

        [parameters{nTime}(sub,:), ll{nTime}(sub,:)] = fmincon(@(params) ...
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
            fit.out.bic{nTime}(sub,:) = -2 * -ll{nTime} + model_param.nfpm * log(total_trial);

        end

    end % End of the loop through nTime

end % End of the loop through subjects

delete(w);

%% SAVE DATA

fit.in.opt = opt;
fit.in.fmin_opt = fmin_opt;
fit.in.model_param = model_param;
fit.in.times = opt.times;

fit.out.params = parameters;
fit.out.ll = ll;

save(fullfile(fileparts(init.path), 'Modelling_results', sprintf('fitting_discrete_win_%s_phase_cecchi2025_%s.mat', opt.phase_fit, opt.task)), 'fit');

%% Figure : grid plot LL stim + out (difference with the best model)

if ismember(opt.time_type, {'prct'})

    opt = fit.in.opt;

    fig = figure;

    xvalues = movmean(fit.in.times, 2, 'Endpoints', 'discard');
    yvalues = 1;

    best_model_nb = 4; % EYE RANGE 1 alpha (stim fix only)
    fit_best = load(fullfile(fileparts(init.path), 'Modelling_results', sprintf('fitting_%s_phase_cecchi2025_%s.mat', opt.phase_fit, opt.task)), 'fit');

    for i = 1:size(fit.out.ll, 1)
        for j = 1:size(fit.out.ll, 2)
            data(i,j) = -mean(fit.out.ll{i,j} - fit_best.fit.out.ll(:,best_model_nb)); % Diffence of LL (grid - best)
        end
    end

    h = heatmap(xvalues, yvalues, data);
    colormap(cool)
    clim([-100 0])

    xlabel('Time from outcomes display (%)')

    % Save
    figSize = [20 10]; % [width height]
    fig.PaperPosition = [0, 0, figSize]; % [left bottom width height]
    fig.PaperSize = figSize;
    fig_name = fullfile(fileparts(init.path), 'Figures', 'Fitting', sprintf('%s_model%d_%s_fit_discrete_window', opt.task, model_idx, fit.in.opt.phase_fit));
    print(fig, fig_name, '-dpdf', '-r200', '-image');

    close(fig)

    %% Repeated measures ANOVA
    ranova_tbl = array2table(cell2mat(fit.out.ll));

    w.time = (1:size(ranova_tbl,2))';
    within = struct2table(w);

    rm = fitrm(ranova_tbl, sprintf('Var1-Var%d ~ 1', size(ranova_tbl,2)), 'WithinDesign', within);
    ranova_results = ranova(rm, 'withinmodel', 'time');

    % Test sphericity
    sphericity_warn(rm)

    % Post-hoc (ranova)
    post_hoc = multcompare(rm, 'time');

    best_win = find(data == max(data));
    alpha = 0.05;
    post_hoc(post_hoc.time_1 == best_win & post_hoc.pValue > alpha,:) % We are looking for the similar ones (i.e. not significant, pvalue > 0.05)

end