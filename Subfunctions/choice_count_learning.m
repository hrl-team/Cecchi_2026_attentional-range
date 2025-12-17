function [out] = choice_count_learning(db, savepath, opt)

% Contexts :
% - NARROW non-forced = Nnf (100% ternary)
% - NARROW semi-forced = Nsf (50% ternary, 50% binary)
% - WIDE non-forced = Wnf
% - WIDE semi-forced = Wsf

opt.part_count = 0;

%% Loop through participants
for part = 1:height(db.header)

    clearvars -except db savepath opt part out

    opt.part_count = opt.part_count + 1;
    condi = db.expe.id == db.header.id(part) & ismember(db.expe.phase, 'learning'); % Select participant learning trials
    learning_data = db.expe(condi,:);

    out.contexts = condi_spec(db.header(part,:));

    % Loop through trials
    condi_count = struct;
    prev_count = struct;
    for trial = 1:height(learning_data) % Loop through trials

        % Get trial condition

        if opt.merge_range % Merge WIDE and NARROW conditions
            condi_name = sprintf('%s', out.contexts(learning_data.condi_id(trial)+1).condi_name(2:end));
        else
            condi_name = sprintf('%s', out.contexts(learning_data.condi_id(trial)+1).condi_name);
        end

        if ~isfield(condi_count, condi_name)
            condi_count.(condi_name) = 1;
        else
            condi_count.(condi_name) = condi_count.(condi_name) + 1;
        end

        choice_pos = learning_data(trial,:).choice_screen_idx + 1;

        for stim = 1:numel(learning_data.stim_mean_values{trial}) % Loop through stimuli

            if opt.merge_range % Merge WIDE and NARROW conditions

                if learning_data.stim_mean_values{trial}(stim) == min(learning_data.stim_mean_values{trial})
                    pos = 'min';
                elseif learning_data.stim_mean_values{trial}(stim) == max(learning_data.stim_mean_values{trial})
                    pos = 'max';
                else
                    pos = 'mid';
                end

                stim_name = sprintf('%s', pos);

            else
                stim_name = sprintf('s%d', learning_data.stim_mean_values{trial}(stim));
            end

            if ~isfield(prev_count, condi_name) || ~isfield(prev_count.(condi_name), stim_name)
                prev_count.(condi_name).(stim_name) = 0;
            else
                prev_count.(condi_name).(stim_name) = out.choice_count.(condi_name).(stim_name)(condi_count.(condi_name)-1, opt.part_count);
            end

            if stim == choice_pos
                out.choice_count.(condi_name).(stim_name)(condi_count.(condi_name), opt.part_count) = prev_count.(condi_name).(stim_name) + 1;
            else
                out.choice_count.(condi_name).(stim_name)(condi_count.(condi_name), opt.part_count) = prev_count.(condi_name).(stim_name);
            end

        end % End of the loop through stimuli
    end % End of the loop through trials
end % End of the loop through participants

clearvars -except db savepath opt out

%% Stats

if opt.stats == 1

    % Repeated measures ANOVA
    choice_rate = structfun(@(x) structfun(@(y) y(end,:)/size(y,1), x, 'UniformOutput', 0), out.choice_count, 'UniformOutput', 0);
    i_fname = fieldnames(choice_rate);

    for i = 1:numel(i_fname)
        j_fname = fieldnames(choice_rate.(i_fname{i}));
        j_fval = cellfun(@(r) str2double(r(2:end)), j_fname);

        for j = 1:numel(j_fname)

            if opt.merge_range
                j_val_name = j_fname{j};
            else
                if j_fval(j) == min(j_fval)
                    j_val_name = 'min';
                elseif j_fval(j) == max(j_fval)
                    j_val_name = 'max';
                else
                    j_val_name = 'mid';
                end
            end
            ranova_data.(strjoin({i_fname{i}, j_val_name}, '_')) = choice_rate.(i_fname{i}).(j_fname{j})';
        end
    end
    ranova_tbl = struct2table(ranova_data);

    fields = fieldnames(ranova_data);
    wi.range_condi = cellfun(@(x) x(1:strfind(x, '_')-1), fields, 'UniformOutput', 0);
    wi.option = cellfun(@(x) x(end-2:end), fields, 'UniformOutput', 0);

    % Create an interaction factor capturing each combination of levels
    wi2 = wi;

    if ~opt.merge_range
        wi2.condi = cellfun(@(x) x(2:strfind(x, '_')-1), fields, 'UniformOutput', 0);
        wi2.range = cellfun(@(x) x(1), fields, 'UniformOutput', 0);
    end

    within = struct2table(wi2);

    rm = fitrm(ranova_tbl, sprintf('%s ~ 1', char(join(fields, ','))), 'WithinDesign', within);
    ranova_results = ranova(rm, 'withinmodel', strjoin(fieldnames(wi), '*')); % condi * option

    % Get partial eta squared
    % Formula : η2p = SS_effect / (SS_effect + SS_error_within)
    SS_effect = ranova_results.SumSq(contains(ranova_results.Properties.RowNames, {'(Intercept)'}));
    SS_error_within = ranova_results.SumSq(contains(ranova_results.Properties.RowNames, {'Error'}));
    ranova_results.partialeta2(contains(ranova_results.Properties.RowNames, {'(Intercept)'})) = SS_effect ./ (SS_effect + SS_error_within);

    fprintf('\n--------------- Repeated measures ANOVA ---------------\n\n')
    disp(ranova_results)

    % Test sphericity
    sphericity_warn(rm)

    % Post-hoc (ranova)
    if ranova_results{['(Intercept):' strjoin(fieldnames(wi), ':')], 'pValueGG'} < .05 % If the interaction is significant

        fprintf('\n--------------- Post-hoc: range_condi by option ---------------\n\n')
        disp(multcompare(rm, 'range_condi', 'by', 'option'))
        fprintf('\n--------------- Post-hoc: option by range_condi ---------------\n\n')
        disp(multcompare(rm, 'option', 'by', 'range_condi'))

    end

end % End of the condition if opt.stats = 1

%% Figure

clearvars -except savepath opt out
condi_names = {out.contexts.condi_name};

if opt.plot == 1 && ~opt.merge_range

    % Figure
    fig = figure;
    t = tiledlayout(2, numel(condi_names)/2, 'TileSpacing', 'Compact');

    for cond = 1:numel(condi_names)

        nexttile
        hold on;

        plot_color = out.contexts(contains({out.contexts.condi_name}, condi_names{cond}),:).color;

        c_name = condi_names{cond};
        s_name = natsort(fieldnames(out.choice_count.(c_name)));

        for stim = 1:numel(s_name)

            stim_data = out.choice_count.(c_name).(s_name{stim});% ./ (1:size(out.choice_count.(c_name).(s_name{stim}),1))';
            stim_mean = mean(stim_data,2);
            stim_sem = std(stim_data,[],2)/sqrt(size(stim_data,2));

            trial_nb = size(out.choice_count.(c_name).(s_name{stim}),1);

            patch([1:trial_nb trial_nb:-1:1],...
                stim_mean([1:end end:-1:1]) + cat(1, stim_sem, -stim_sem(end:-1:1)),...
                plot_color,'EdgeColor','none','FaceAlpha',.4)

            p(stim) = plot(stim_mean);
            p(stim).Color = plot_color;
            p(stim).LineWidth = 1.5;

            switch stim
                case 1
                    p(stim).LineStyle = ':';
                case 2
                    p(stim).LineStyle = "--";
                case 3
                    p(stim).LineStyle = '-';
            end

        end % End of the loop through stimuli

        xlim([1 trial_nb]);
        ylim([0 trial_nb]);
        % ylim([0 1]);

        title(condi_names{cond});
        s_val = cellfun(@(x) regexp(x, '(?<=s)\w*', 'match'), s_name);
        legend(p, s_val, 'Location', 'northwest');

    end % End of the loop through conditions

    % Labels
    xlabel(t,'Trials')
    ylabel(t,'Cumulated choice count')

    %% Save
    figSize = [15 20]; % [width height]
    fig.PaperPosition = [0, 0, figSize]; % [left bottom width height]
    fig.PaperSize = figSize;
    fig_name = fullfile(savepath, 'Figures', 'Behavior', sprintf('%s_choice_count_learning', opt.task));
    print(fig, fig_name, '-dpdf', '-r200', '-image');

    close(fig)

elseif opt.plot == 1 && opt.merge_range

    % Merged WIDE and NARROW conditions

    % Figure
    fig = figure;
    t = tiledlayout(1, numel(condi_names)/2, 'TileSpacing', 'Compact');

    merged_condi = 'WN';
    stim_val = {'min', 'mid', 'max'};
    forced_condi = fieldnames(out.choice_count);

    for f = 1:numel(forced_condi)

        nexttile
        hold on;

        plot_color = mean(vertcat(out.contexts(contains({out.contexts.condi_name}, {forced_condi{f}(2:end)}),:).color));

        for stim = 1:numel(stim_val)

            c_name = forced_condi{f};
            s_name = natsort(fieldnames(out.choice_count.(c_name)));

            stim_data = out.choice_count.(c_name).(s_name{stim});

            stim_mean = mean(stim_data,2);
            stim_sem = std(stim_data,[],2)/sqrt(size(stim_data,2));

            trial_nb = length(stim_mean);

            patch([1:trial_nb trial_nb:-1:1],...
                stim_mean([1:end end:-1:1]) + cat(1, stim_sem, -stim_sem(end:-1:1)),...
                plot_color,'EdgeColor','none','FaceAlpha',.4)

            p(stim) = plot(stim_mean);
            p(stim).Color = plot_color;
            p(stim).LineWidth = 1.5;

            switch stim
                case 1
                    p(stim).LineStyle = ':';
                case 2
                    p(stim).LineStyle = "--";
                case 3
                    p(stim).LineStyle = '-';
            end

        end % End of the loop through stimuli

        xlim([1 trial_nb]);
        ylim([0 trial_nb]);

        title(forced_condi{f}(2:end));
        legend(p, stim_val, 'Location', 'northwest');

    end % End of the loop through forced_condi

    % Labels
    xlabel(t,'Trials')
    ylabel(t,'Cumulated choice count')

    %% Save
    figSize = [15 10]; % [width height]
    fig.PaperPosition = [0, 0, figSize]; % [left bottom width height]
    fig.PaperSize = figSize;
    fig_name = fullfile(savepath, 'Figures', 'Behavior', sprintf('%s_choice_count_learning_merged_range', opt.task));
    print(fig, fig_name, '-dpdf', '-r200', '-image');

    close(fig)

end % End of the condition if opt.plot = 1

end