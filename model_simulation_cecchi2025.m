%% Simulations for a three-armed bandit
% -------------------------------------
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
clear all
rng(100) % To keep same results when we redo it

%% MODELS

% 1:  Q-LEARNING 1 alpha (= pas de normalisation = Qvaleur de 0 à 100)
% 2:  RANGE 1 alpha 2 omega -> 1 omega by condition
% 3:  EYE RANGE 1 alpha + 1 phi (weighted sum of stim and out fix)
% 4:  EYE RANGE 1 alpha (stim fix only)
% 5:  EYE RANGE 1 alpha (out fix only)
% 6:  EYE only 1 alpha + 1 phi (weighted sum of stim and out fix)
% 7:  EYE only 1 alpha (stim fix only)
% 8:  EYE only 1 alpha (out fix only)
% 9:  RANGE EYE 1 alpha + 1 phi (weighted sum of stim and out fix)
% 10: RANGE EYE 1 alpha (stim fix only)
% 11: RANGE EYE 1 alpha (out fix only)
% 12: Power-law compression
% 13: RANGE 1 alpha 1 epsilon [Argmax + Epsilon-greedy in transfer]
% 14: Choice perseveration (Katahira)
% 15: model_fitting_incremental_window.m
% 16: model_fitting_discrete_window.m

%% Options

opt.task = 'e3_lum_out'; % 'e1_forced'|'e2_lum_stim'|'e3_lum_out'
opt.model_idx = [4 12 14]; % Model to run

opt.fit_phase = 'learning'; % Phase on which the model was fitted: 'learning' (all models except e-greedy) | 'both'

% Data path
init.path = '/Users/romane/Documents/Pub_codes/Cecchi_2025_attention_norm_RL/Data';

%%

opt.sim_type = 'ex_post';
% - ex post: Use best fitting parameters for each subject (simulate 'opt.repet' times for each subject with their own fitted parameters)

opt.repet = 100; % Simulation number
opt.modeling_step = 'simulation';

%% Import database tables
% Header: 1 line = 1 participant
% Expe: 1 line = 1 trial

db = load(fullfile(init.path, sprintf('%s_data.mat', opt.task)), 'header', 'expe');

%% Load fitted data

fit_file = sprintf('fitting_%s_phase_cecchi2025_%s.mat', opt.fit_phase, opt.task);

try
    load(fullfile(fileparts(init.path), 'Modelling_results', fit_file), 'fit');
catch
    error(sprintf('The file "%s" does not exist in "%s".\nPerform fitting before simulation (with "model_fitting_cecchi2025.m")', fit_file, fullfile(fileparts(init.path), 'Modelling_results')), init.path);
end

%% Load real data

opt.plot = 0;
opt.stats = 0;
opt.merge_range = 0;

real_data.learning = choice_rate_learning(db, '', opt); % Choice rate learning
real_data.transfer = choice_rate_transfer(db, '', opt); % Choice rate transfer

%% Loop through models

for model_idx = opt.model_idx

    % Initialization

    if strcmp(opt.sim_type, {'ex_post'})
        parameters = fit.out.params(:,:,model_idx); % Parameters of the fitting step for all participants
    end

    w = waitbar(0, 'Starting...');

    %% Simulation

    for n = 1:opt.repet % Loop through repetitions

        waitbar(n/opt.repet, w, sprintf('Model %d simulation: Iteration n°%d / %d', model_idx, n, opt.repet));

        if strcmp(opt.sim_type, {'ex_post'})
            for sub = 1:height(db.header) % Loop through subjects

                sub_parameters = parameters(sub,:);
                sub_header = db.header(sub,:);
                sub_learning_data = fit.in.data(sub).learning;

                data_sub = format_sub_data_for_simulation(sub_header, sub_learning_data);

                % Simulation -------------------------------------------- %
                [~, out_sub] = threeArmedBandit_models_run_cecchi2025(sub_parameters, data_sub, model_idx, opt.modeling_step);

                % Recreate learning and transfer phases ----------------- %
                [out.learning_choice_proba(:,:,:,sub,n), out.transfer_choice_proba(:,:,sub,n)] = sim_learning_and_transfer_phases(data_sub, out_sub.choice_proba);

                out.Q_time(:,:,:,sub,n) = out_sub.Q_time;

                if model_idx == 14 % Perseveration
                    out.C_trace(:,:,:,sub,n) = out_sub.C_trace;
                end

            end % End of the loop through subjects
        end

    end % End of the loop through repetitions

    delete(w);

    if strcmp(opt.sim_type, {'ex_post'})

        % Average output data across repetitions
        out.learning_choice_proba = mean(out.learning_choice_proba, 5); % condi * option (from worst to best) * trial type * subject
        out.transfer_choice_proba = mean(out.transfer_choice_proba, 4); % condi * option (from worst to best) * subject
        out.Q_time = mean(out.Q_time, 5); % condi * option (from worst to best) * trial * subject

        if model_idx == 14 % Perseveration
            out.C_trace = mean(out.C_trace, 5); % condi * option (from worst to best) * trial * subject
        end

    end

    contexts = condi_spec(sub_header); % Load contexts spec.

    %% Plot LEARNING choice rate

    % Plot the figure
    fig = figure;

    if strcmp(opt.task, 'e1_forced')

        t = tiledlayout(2, numel(contexts), 'TileSpacing', 'Compact');

        trial_type = {'ternary', 'binary'}; % Keep this order or change how learning is re-created

        for type = 1:numel(trial_type)
            for cond = 1:numel(contexts)

                nexttile
                hold on; grid on;

                color = contexts(cond).color;

                % Real data
                r_data = real_data.learning.choice_rate.(trial_type{type})(cond);

                for stim = 1:numel(contexts(cond).imgMean) % Loop through context options

                    opt_name = sprintf('opt%d', contexts(cond).imgMean(stim));
                    r_data_rate = r_data.(opt_name);
                    r_mean = mean(r_data_rate);
                    r_sem = std(r_data_rate)/sqrt(numel(r_data_rate));

                    errorbar(stim, r_mean, r_sem, 'Color', color, 'LineStyle', 'none');
                    r = bar(stim, r_mean, 'FaceColor', color, 'EdgeColor', 'none');

                end % End of the loop through options

                % Simulated data
                s_data = squeeze(out.learning_choice_proba(cond,:,type,:))'; % Subj * options
                s_mean = mean(s_data);
                s_sem = std(s_data)/sqrt(size(s_data,1));

                s = errorbar(1:numel(s_mean), s_mean, s_sem, 'ok', 'MarkerFaceColor', 'black', 'MarkerEdgeColor', 'none'); % Transfer choice rate of the model

                % Axes
                title(sprintf('%s', contexts(cond).condi_name))

                xticks(1:stim)
                xticklabels(contexts(cond).imgMean)
                xlim([0 stim+1]);
                ylim([0 1]);

                if cond == numel(contexts)
                    legend([s,r], {'Simulation', 'Real data'}, 'Location', 'best')
                end

            end % End of the loop through conditions
        end % End of the loop through ternary/binary conditions

        figSize = [30 20]; % [width height]

    else

        t = tiledlayout(1, numel(contexts), 'TileSpacing', 'Compact');

        for cond = 1:numel(contexts)

            nexttile
            hold on; grid on;

            color = contexts(cond).color;

            % Real data
            r_data = real_data.learning.choice_rate_all(cond);

            for stim = 1:numel(contexts(cond).imgMean) % Loop through context options

                opt_name = sprintf('opt%d', contexts(cond).imgMean(stim));
                r_data_rate = r_data.(opt_name);
                r_mean = mean(r_data_rate);
                r_sem = std(r_data_rate)/sqrt(numel(r_data_rate));

                errorbar(stim, r_mean, r_sem, 'Color', color, 'LineStyle', 'none');
                r = bar(stim, r_mean, 'FaceColor', color, 'EdgeColor', 'none');

            end % End of the loop through options

            % Simulated data

            if ~all(all(isnan(out.learning_choice_proba(cond,:,2,:))))
                out.learning_choice_proba(cond,3,2,:) = 0; % Put zero when the option couldn't be chosen
            end

            s_data = squeeze(mean(out.learning_choice_proba(cond,:,:,:), 3, 'omitnan'))'; % Subj * options
            s_mean = mean(s_data);
            s_sem = std(s_data)/sqrt(size(s_data,1));

            s = errorbar(1:numel(s_mean), s_mean, s_sem, 'ok', 'MarkerFaceColor', 'black', 'MarkerEdgeColor', 'none'); % Transfer choice rate of the model

            % Axes
            title(sprintf('%s', contexts(cond).condi_name))

            xticks(1:stim)
            xticklabels(contexts(cond).imgMean)
            xlim([0 stim+1]);
            ylim([0 1]);

            if cond == numel(contexts)
                legend([s,r], {'Simulation', 'Real data'}, 'Location', 'best')
            end

        end % End of the loop through conditions

        figSize = [30 10]; % [width height]

    end % End of the "task" condition

    xlabel(t,'Option value')
    ylabel(t,'Learning choice rate')

    title(t, sprintf('%s simulations', regexprep(lower(strrep(opt.sim_type, '_', ' ')),'^.', '${upper($0)}')))
    if contains(opt.sim_type, {'ex_post'})
        subtitle(t, sprintf('fitted on %s', fit.in.opt.phase_fit));
    end

    % Save
    fig.PaperPosition = [0, 0, figSize]; % [left bottom width height]
    fig.PaperSize = figSize;
    fig_name = fullfile(fileparts(init.path), 'Figures', 'Simulation', sprintf('%s_model%d_%s_fit_choice_rate_learning_%s', opt.task, model_idx, fit.in.opt.phase_fit, opt.sim_type));
    print(fig, fig_name, '-dpdf', '-r200', '-image');

    close(fig)

    %% Plot TRANSFER choice rate

    % Plot the figure
    fig = figure;
    t = tiledlayout(1, numel(contexts), 'TileSpacing', 'Compact');

    for cond = 1:numel(contexts)

        nexttile
        hold on; grid on;

        color = contexts(cond).color;

        % Real data
        r_data = real_data.transfer.choice_rate(cond);

        for stim = 1:numel(contexts(cond).imgMean) % Loop through context options

            opt_name = sprintf('opt%d', contexts(cond).imgMean(stim));
            r_data_rate = r_data.(opt_name);
            r_mean = mean(r_data_rate);
            r_sem = std(r_data_rate)/sqrt(numel(r_data_rate));

            errorbar(stim, r_mean, r_sem, 'Color', color, 'LineStyle', 'none');
            r = bar(stim, r_mean, 'FaceColor', color, 'EdgeColor', 'none');

        end % End of the loop through options

        % Simulated data
        s_data = squeeze(out.transfer_choice_proba(cond,:,:))'; % Subj * options
        s_mean = mean(s_data);
        s_sem = std(s_data)/sqrt(size(s_data,1));

        s = errorbar(1:numel(s_mean), s_mean, s_sem, '-ok', 'MarkerFaceColor', 'black', 'MarkerEdgeColor', 'none'); % Transfer choice rate of the model

        % Axes
        title(sprintf('%s', contexts(cond).condi_name))

        xticks(1:stim)
        xticklabels(contexts(cond).imgMean)
        xlim([0 stim+1]);
        ylim([0 1]);

        if cond == numel(contexts)
            legend([s,r], {'Simulation', 'Real data'}, 'Location', 'best')
        end

    end % End of the loop through conditions

    xlabel(t,'Option value')
    ylabel(t,'Transfer choice rate')

    title(t, sprintf('%s simulations', regexprep(lower(strrep(opt.sim_type, '_', ' ')),'^.', '${upper($0)}')))
    if contains(opt.sim_type, {'ex_post'})
        subtitle(t, sprintf('fitted on %s', fit.in.opt.phase_fit));
    end

    % Save
    figSize = [30 10]; % [width height]
    fig.PaperPosition = [0, 0, figSize]; % [left bottom width height]
    fig.PaperSize = figSize;
    fig_name = fullfile(fileparts(init.path), 'Figures', 'Simulation', sprintf('%s_model%d_%s_fit_choice_rate_transfer_%s', opt.task, model_idx, fit.in.opt.phase_fit, opt.sim_type));
    print(fig, fig_name, '-dpdf', '-r200', '-image');

    close(fig)

    %% Plot Q-values evolution

    fig = figure;
    t = tiledlayout(1, height(contexts), 'TileSpacing', 'Compact');

    for condi = 1:height(contexts)

        nexttile
        hold on

        for stim = 1:numel(contexts(condi).imgMean)

            plot_data = squeeze(out.Q_time(condi,stim,:,:)); % Time * Subj
            mean_data = mean(plot_data,2);
            sem_data = std(plot_data,[],2) / sqrt(size(plot_data,2));

            switch stim % Matlab colors
                case 1
                    plot_color = [0 0.4470 0.7410];
                case 2
                    plot_color = [0.8500 0.3250 0.0980];
                case 3
                    plot_color = [0.9290 0.6940 0.1250];
            end

            patch([1:size(plot_data,1) size(plot_data,1):-1:1],...
                mean_data([1:size(plot_data,1) size(plot_data,1):-1:1]) + cat(1, sem_data(1:size(plot_data,1)), -sem_data(size(plot_data,1):-1:1)),...
                plot_color,'EdgeColor','none','FaceAlpha',.3)

            p_q(stim) = plot(mean_data, 'Color', plot_color);
            title(contexts(condi).condi_name)

        end

        legend(p_q, {'min', 'mid', 'max'});

        xlim([1 size(plot_data,1)])
        if ismember(model_idx, [1 12 14])
            ylim([0 100])
        else
            ylim([0 1])
        end
    end

    title(t, 'Q values')

    % Save
    figSize = [30 15]; % [width height]
    fig.PaperPosition = [0, 0, figSize]; % [left bottom width height]
    fig.PaperSize = figSize;
    fig_name = fullfile(fileparts(init.path), 'Figures', 'Simulation', sprintf('%s_model%d_%s_fit_Q_val_%s', opt.task, model_idx, fit.in.opt.phase_fit, opt.sim_type));
    print(fig, fig_name, '-dpdf', '-r200', '-image');

    close(fig)

    %% Plot C-trace evolution

    if model_idx == 14 % Perseveration model

        fig = figure;
        t = tiledlayout(1, height(contexts), 'TileSpacing', 'Compact');

        for condi = 1:height(contexts)

            nexttile
            hold on

            for stim = 1:numel(contexts(condi).imgMean)

                plot_data = squeeze(out.C_trace(condi,stim,:,:)); % Time * Subj
                mean_data = mean(plot_data,2);
                sem_data = std(plot_data,[],2) / sqrt(size(plot_data,2));

                switch stim % Matlab colors
                    case 1
                        plot_color = [0 0.4470 0.7410];
                    case 2
                        plot_color = [0.8500 0.3250 0.0980];
                    case 3
                        plot_color = [0.9290 0.6940 0.1250];
                    case 4
                        plot_color = [0.4940 0.1840 0.5560];
                end

                patch([1:size(plot_data,1) size(plot_data,1):-1:1],...
                    mean_data([1:size(plot_data,1) size(plot_data,1):-1:1]) + cat(1, sem_data(1:size(plot_data,1)), -sem_data(size(plot_data,1):-1:1)),...
                    plot_color,'EdgeColor','none','FaceAlpha',.3)

                p_c(stim) = plot(mean_data, 'Color', plot_color);
                title(contexts(condi).condi_name)

            end

            legend(p_c, {'min', 'mid', 'max'});

            xlim([1 size(plot_data,1)])
            ylim([0 1])
        end

        title(t, 'C trace')

        close(fig)
    end

    %% Plot Q-value + C-trace evolution

    if model_idx == 14 % Perseveration model

        fig = figure;
        t = tiledlayout(1, height(contexts), 'TileSpacing', 'Compact');

        for condi = 1:height(contexts)

            nexttile
            hold on

            for stim = 1:numel(contexts(condi).imgMean)

                Q_value = squeeze(out.Q_time(condi,stim,:,:)); % Time * Subj
                C_trace = squeeze(out.C_trace(condi,stim,:,:)); % Time * Subj

                beta = mean(parameters(:,contains(fit.in.model_param(model_idx).names, {'beta'})));
                phi = mean(parameters(:,contains(fit.in.model_param(model_idx).names, {'phi_choice'})));

                Q_plus_C = (beta' .* Q_value) + (phi' .* C_trace); % Time * Subj

                plot_data = Q_plus_C;
                mean_data = mean(plot_data,2);
                sem_data = std(plot_data,[],2) / sqrt(size(plot_data,2));

                switch stim % Matlab colors
                    case 1
                        plot_color = [0 0.4470 0.7410];
                    case 2
                        plot_color = [0.8500 0.3250 0.0980];
                    case 3
                        plot_color = [0.9290 0.6940 0.1250];
                    case 4
                        plot_color = [0.4940 0.1840 0.5560];
                end

                patch([1:size(plot_data,1) size(plot_data,1):-1:1],...
                    mean_data([1:size(plot_data,1) size(plot_data,1):-1:1]) + cat(1, sem_data(1:size(plot_data,1)), -sem_data(size(plot_data,1):-1:1)),...
                    plot_color,'EdgeColor','none','FaceAlpha',.3)

                p_qc(stim) = plot(mean_data, 'Color', plot_color);
                title(contexts(condi).condi_name)

            end

            legend(p_qc, {'min', 'mid', 'max'});

            xlim([1 size(plot_data,1)])
            ylim([0 100])

        end

        title(t, 'Q value + C trace')

        close(fig)
    end

    %% For backup
    simulation{model_idx} = out;

end % End of the loop through models

%% SAVE DATA

save(fullfile(fileparts(init.path), 'Modelling_results', sprintf('simulation_%s_%s_phase_fit_cecchi2025_%s.mat', opt.sim_type, opt.fit_phase, opt.task)), 'simulation');
