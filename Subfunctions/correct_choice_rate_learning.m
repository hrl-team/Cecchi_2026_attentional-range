function correct_choice_rate_learning(db, savepath, opt)
% Correct choice rate = the probability of choosing the option with the
% highest expected value (among the selectable options)

% Contexts :
% - NARROW non-forced = Nnf
% - NARROW semi-forced = Nsf
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

    % Loop through contexts
    for cont = 1:numel(out.contexts)

        choice_nb = 0;
        correct_choice_nb = 0;

        condi_data = learning_data(learning_data.condi_id == (cont-1),:);

        ternary_trials_nb = 0;
        correct_ternary_nb = 0;
        binary_trials_nb = 0;
        correct_binary_nb = 0;

        for trial = 1:height(condi_data) % Loop through trials

            if ismember('stim_is_clickable', condi_data.Properties.VariableNames) && sum(condi_data.stim_is_clickable{trial}) > 1 % More than one possible option

                choice_nb = choice_nb + 1;
                correct_choice = max(condi_data.stim_outcomes{trial} .* condi_data.stim_is_clickable{trial}); % Correct choice among SELECTABLE options only
                choiceIsCorrect = condi_data.choice_outcome(trial) == correct_choice;

                correct_choice_nb = correct_choice_nb + choiceIsCorrect;

            elseif ismember('out_is_higher_lumi', condi_data.Properties.VariableNames)

                choice_nb = choice_nb + 1;
                correct_choice = max(condi_data.stim_outcomes{trial}); % Correct choice
                choiceIsCorrect = condi_data.choice_outcome(trial) == correct_choice;

                if choiceIsCorrect % The choice is correct
                    correct_choice_nb = correct_choice_nb + 1;
                end

            end

            if contains(opt.task, {'forced'}) % Forced task
                nary = sum(condi_data.stim_is_clickable{trial});
            elseif contains(opt.task, {'lum'}) % Luminance task
                nary = find(sort(condi_data.stim_mean_values{trial}) == ...
                    nonzeros(condi_data.stim_mean_values{trial} .* condi_data.out_is_higher_lumi{trial}));
            end

            if nary == 3
                ternary_trials_nb = ternary_trials_nb + 1;
                correct_ternary_nb = correct_ternary_nb + choiceIsCorrect;
            elseif nary == 2
                binary_trials_nb = binary_trials_nb + 1;
                correct_binary_nb = correct_binary_nb + choiceIsCorrect;
            end

        end % End of the loop through trials

        out.correct_choice_rate(opt.part_count, cont) = correct_choice_nb / choice_nb; % Participant * Condi

        out.correct_choice_rate_ternary(opt.part_count, cont) = correct_ternary_nb / ternary_trials_nb; % Correct choice rate only for ternary trials
        out.correct_choice_rate_binary(opt.part_count, cont) = correct_binary_nb / binary_trials_nb; % Correct choice rate only for ternary trials

    end % End of the loop through contexts
end % End of the loop through participants

clearvars -except savepath opt out

%% Stats

if opt.stats == 1

    if contains(opt.task, {'forced'}) % Forced task
        nary = {'_ternary', '_binary'};
    elseif contains(opt.task, {'lum'}) % Luminance task
        nary = {''};
    end

    fprintf('--------------- T-tests ---------------\n')

    for i = 1:numel(nary)

        condi_name = sprintf('correct_choice_rate%s', nary{i});
        mean_condi = mean(out.(condi_name));
        sd_condi = std(out.(condi_name));

        if ismember(nary{i}, {'_ternary'})
            chance = 1/3;
        elseif ismember(nary{i}, {'_binary', ''})
            if contains(opt.task, {'forced'}) % Forced task
                chance = 1/2;
            elseif contains(opt.task, {'lum'}) % Luminance task
                chance = 1/3;
            end
        end

        % % One-sample t-tests
        [~,p,ci,stats] = ttest(out.(condi_name), chance);

        effect_size = NaN(size(mean_condi));
        for j = 1:size(out.(condi_name),2)
            if ~all(isnan(out.(condi_name)(:,j)))
                effect = meanEffectSize(out.(condi_name)(:,j), 'Effect', 'cohen', 'Mean', chance);
                effect_size(j) = effect.Effect;
            end
        end

        array2table([mean_condi', sd_condi', stats.df', stats.tstat', p', ci(1,:)', ci(2,:)', effect_size'], 'VariableNames', {'mean', 'sd', 'df', 't', 'p', 'CI1', 'CI2', 'd'}, 'RowName', {out.contexts.condi_name})

    end

    % ----------------------------------------------------------------------- %

    % Repeated measures ANOVA
    fprintf('\n--------------- Repeated measures ANOVA ---------------\n\n')

    ranova_tbl = array2table(out.correct_choice_rate);

    w.range = cellfun(@(x) x(1), {out.contexts.condi_name}, 'UniformOutput', 0)';
    w.trial_type = cellfun(@(x) x(2:end), {out.contexts.condi_name}, 'UniformOutput', 0)';
    within = struct2table(w);

    rm = fitrm(ranova_tbl, sprintf('Var1-Var%d ~ 1', size(ranova_tbl,2)), 'WithinDesign', within);
    ranova_results = ranova(rm, 'withinmodel', 'range * trial_type');

    % Get partial eta squared
    % Formula : η2p = SS_effect / (SS_effect + SS_error_within)
    SS_effect = ranova_results.SumSq(contains(ranova_results.Properties.RowNames, {'(Intercept)'}));
    SS_error_within = ranova_results.SumSq(contains(ranova_results.Properties.RowNames, {'Error'}));
    ranova_results.partialeta2(contains(ranova_results.Properties.RowNames, {'(Intercept)'})) = SS_effect ./ (SS_effect + SS_error_within);

    disp(ranova_results)

    % Sphericity test
    sphericity_warn(rm)

end % End of the condition if opt.stats = 1

%% Figure

if opt.plot

    clearvars -except db savepath opt out

    fig = figure;
    hold on

    trial_type = {'100', '50'};
    nary = {'ternary', 'binary'};
    o.pos = 0;

    for i = 1:numel(nary)

        data = out.(sprintf('correct_choice_rate_%s', nary{i}));

        for h = 1:numel(trial_type)

            % Find columns corresponding to the trial type
            trial_type_col = find(contains({out.contexts.condi_name}, trial_type(h)));

            for j = trial_type_col
                if any(~isnan(data(:,j)))

                    o.showData = true;
                    o.violinSpace = 'right';
                    o.color = out.contexts(j).color;
                    o.connectDots = false;
                    o.pos = o.pos + 1;

                    violaPlot(data(:,j), o)

                    % Get condi name
                    if contains(opt.task, {'forced'}) % Forced task
                        if ismember(nary{i}, {'ternary'})
                            suf = '3opt';
                        elseif ismember(nary{i}, {'binary'})
                            suf = '2opt';
                        end
                    elseif contains(opt.task, {'lum'}) % Luminance task
                        if ismember(nary{i}, {'ternary'})
                            suf = 'high-value';
                        elseif ismember(nary{i}, {'binary'})
                            suf = 'mid-value';
                        end
                    end

                    condi_name{o.pos} = sprintf('%s-%s', out.contexts(j).condi_name, suf);

                end
            end
        end
    end

    xlim([.5 o.pos + 0.5])
    xticks(1:o.pos)
    xticklabels(condi_name)
    xlabel('Learning context')

    ylim([0 1])
    yticks(0:.2:1)
    ylabel('Correct choice rate')

    % Line
    Xlim = xlim;
    yl = plot(Xlim, [1/3 1/3], 'k--', 'LineWidth', .5);
    uistack(yl,'bottom')

    yl = plot(Xlim, [1/2 1/2], 'k--', 'LineWidth', .5);
    uistack(yl,'bottom')

    % Save
    figSize = [25 20]; % [width height]
    fig.PaperPosition = [0, 0, figSize]; % [left bottom width height]
    fig.PaperSize = figSize;
    fig_name = fullfile(savepath, 'Figures', 'Behavior', sprintf('%s_correct_choice_rate_learning', opt.task));
    print(fig, fig_name, '-dpdf', '-r200');

    close(fig)

end

end