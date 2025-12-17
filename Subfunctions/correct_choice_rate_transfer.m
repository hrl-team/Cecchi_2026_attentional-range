function [out] = correct_choice_rate_transfer(db, opt)

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
    condi = db.expe.id == db.header.id(part) & ismember(db.expe.phase, 'transfer'); % Select participant transfer trials
    transfer_data = db.expe(condi,:);

    out.contexts = condi_spec(db.header(part,:));

    correct_choice = 0;

    % Loop through trials
    for trial = 1:height(transfer_data)

        choice_val = transfer_data.stim_mean_values{trial}(transfer_data.choice_screen_idx(trial)+1);
        isCorrect = choice_val == max(transfer_data.stim_mean_values{trial});
        correct_choice = correct_choice + isCorrect;

    end

    out.correct_choice_rate(opt.part_count,:) = correct_choice / height(transfer_data);

end % End of the loop through participants

clearvars -except db savepath opt out

%% Stats

if opt.stats == 1

    % One-sample t-test
    [~,p,ci,stats] = ttest(out.correct_choice_rate, 1/2);
    EffectSize = meanEffectSize(out.correct_choice_rate, 'Effect', 'cohen', 'Mean', 1/2);

    % Display
    fprintf('--------------- One-sample t-test ---------------\n')
    array2table([mean(out.correct_choice_rate)', std(out.correct_choice_rate)', stats.df', stats.tstat', p', ci(1,:)', ci(2,:)', EffectSize.Effect'], 'VariableNames', {'mean', 'sd', 'df', 't', 'p', 'CI1', 'CI2', 'd'}, 'RowName', {'Correct choice rate'})

end % End of the condition if opt.stats = 1

end