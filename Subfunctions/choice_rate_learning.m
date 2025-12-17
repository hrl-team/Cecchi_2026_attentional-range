function [out] = choice_rate_learning(db, savepath, opt)

% Contexts :
% - NARROW non-forced = Nnf
% - NARROW semi-forced = Nsf
% - WIDE non-forced = Wnf
% - WIDE semi-forced = Wsf

opt.count = 0;

%% Loop through participants

for part = 1:height(db.header)

    clearvars -except db savepath opt part out

    opt.count = opt.count + 1;
    condi = db.expe.id == db.header.id(part) & ismember(db.expe.phase, 'learning'); % Select participant learning trials
    learning_data = db.expe(condi,:);

    out.contexts = condi_spec(db.header(part,:));

    % Loop through contexts
    for cont = 1:numel(out.contexts)
        for img = 1:numel(out.contexts(cont).imgName) % Loop through options of the context

            counter.binary = 0; % Nb of times the option was presented
            counter.ternary = 0;

            chosen.binary = 0; % Nb of times the option was chosen
            chosen.ternary = 0;

            imgName = out.contexts(cont).imgName{img};
            imgVal = out.contexts(cont).imgMean(img);

            for trial = 1:height(learning_data) % Loop through trials

                trial_choice_idx = learning_data.choice_screen_idx(trial) + 1; % Index of the chosen option
                stimPos = find(ismember(learning_data.stim_id{trial}, imgName)); % Context option index

                if contains(opt.task, {'forced'}) % Forced task
                    nary = sum(learning_data.stim_is_clickable{trial});
                elseif contains(opt.task, {'lum'}) % Luminance task
                    nary = find(sort(learning_data.stim_mean_values{trial}) == ...
                        nonzeros(learning_data.stim_mean_values{trial} .* learning_data.out_is_higher_lumi{trial}));
                end

                if ~isempty(stimPos) % Stim was in trial
                    if nary == 3 % Ternary
                        counter.ternary = counter.ternary + 1;
                        if stimPos == trial_choice_idx % If the image was chosen
                            chosen.ternary = chosen.ternary + 1;
                        end
                    elseif nary == 2 % Binary
                        counter.binary = counter.binary + 1;
                        if stimPos == trial_choice_idx % If the image was chosen
                            chosen.binary = chosen.binary + 1;
                        end
                    end
                end

            end % End of the loop through trials

            out.choice_rate.ternary(cont).(sprintf('opt%g', imgVal))(opt.count) = chosen.ternary / counter.ternary; % Ternary
            out.choice_rate.binary(cont).(sprintf('opt%g', imgVal))(opt.count) = chosen.binary / counter.binary; % Binary
            out.choice_rate_all(cont).(sprintf('opt%g', imgVal))(opt.count) = sum(cell2mat(struct2cell(chosen))) / sum(cell2mat(struct2cell(counter)));

        end % End of the loop through options of the context
    end % End of the loop through contexts

    if opt.merge_range % Merge WIDE and NARROW conditions

        out.mergedCondName = {'100', '50'};
        newFields = {'min', 'mid', 'max'};

        for c = 1:numel(out.mergedCondName)
            cond2merge = find(contains({out.contexts.condi_name}, out.mergedCondName(c)));
            for ii = 1:numel(newFields)
                choice_rate = [];
                for m = 1:numel(cond2merge)
                    imgMean = sprintf('opt%d', out.contexts(cond2merge(m)).imgMean(ii));
                    choice_rate(m) = out.choice_rate_all(cond2merge(m)).(imgMean)(part);
                end
                out.choice_rate_mergedWN.(out.mergedCondName{c}).(newFields{ii})(part) = mean(choice_rate);
            end
        end

    end % End of if opt.merge_range == 1
end % End of the loop through participants

%% Figure

clearvars -except db savepath opt out

if opt.plot == 1

    % Figure
    fig = figure;
    t = tiledlayout(2, numel(out.contexts), 'TileSpacing', 'Compact');

    optNbCond = fieldnames(out.choice_rate);

    for nbOpt = 1:numel(optNbCond)
        for cond = 1:numel(out.contexts)

            nexttile
            hold on;
            count = 0;

            choiceRate = out.choice_rate.(optNbCond{nbOpt})(cond);
            condField = fieldnames(choiceRate);
            condField = sort(condField(~structfun(@isempty, choiceRate))); % Remove empty fields + sort them

            for field = 1:numel(condField)

                count = count + 1;
                data = choiceRate.(condField{field});
                data(isnan(data)) = 0; % Replace NaNs by zeros

                o.violinSpace = 'right';
                o.pos = count;
                o.showData = true;
                o.color = out.contexts(cond).color;

                violaPlot(data, o)

                xLabels{field} = condField{field}(isstrprop(condField{field}, 'digit'));

            end

            % Axis labelling
            xticks(1:count)
            xticklabels(xLabels)

            if nbOpt == 1
                title(out.contexts(cond).condi_name);
            end

            ylim([0 1]);
            xlim([0 count+1]);

            % Paired t-tests
            plot_paired_ttest(choiceRate)

            % Line
            if ismember(optNbCond{nbOpt}, {'ternary'})
                chance = 1/3;
            elseif ismember(optNbCond{nbOpt}, {'binary'})
                chance = 1/2;
            end
            yl = plot(xlim, [chance chance], 'k--', 'LineWidth', .5);
            uistack(yl,'bottom')

            if ismember(opt.task, {'forced'}) && cond == 1
                ylabel(optNbCond{nbOpt})
            elseif ismember(opt.task, {'lum'}) && cond == 1
                if ismember(optNbCond{nbOpt}, {'ternary'})
                    ylabel('Lum on max outcome')
                elseif ismember(optNbCond{nbOpt}, {'binary'})
                    ylabel('Lum on mid outcome')
                end
            end

        end % End of the loop through conditions
    end % End of the loop through ternary/binary conditions

    xlabel(t,'Option value')
    ylabel(t,'Learning choice rate')

    % Save
    figSize = [40 20]; % [width height]
    fig.PaperPosition = [0, 0, figSize]; % [left bottom width height]
    fig.PaperSize = figSize;
    fig_name = fullfile(savepath, 'Figures', 'Behavior', sprintf('%s_choice_rate_learning', opt.task));
    print(fig, fig_name, '-dpdf', '-r200', '-image');

    close(fig)

end % End of the condition if opt.plot = 1
end