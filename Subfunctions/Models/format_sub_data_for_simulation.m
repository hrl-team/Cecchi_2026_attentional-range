function data_subj = format_sub_data_for_simulation(sub_header, sub_learning_data)

rng('shuffle') % Initialize the generator seed based on the current time (i.e., get a different sequence of random numbers after each call to rng)
contexts = condi_spec(sub_header); % Load contexts spec.

transfer.trial_nb = sub_header.exp_param{:}.transferNbTrials;

%% Behavioral data

rand_idx_learning = randperm(length(sub_learning_data.cond_idx));
data_subj.learning.cond_idx = sub_learning_data.cond_idx(rand_idx_learning); % Random condition index (1 to 4 ; negative = forced choice)
data_subj.learning.img_id = sub_learning_data.img_id; % Matrix similar to the Q-value matrix (condi * options, from worst to best) with the corresponding image names

data_subj.transfer.img_id = repmat(nchoosek(1:sum([contexts.nbChoiceOpt]),2), transfer.trial_nb, 1); % All possible binary combinations between stimuli (i.e., transfer test)
rand_idx_transfer = randperm(length(data_subj.transfer.img_id));
data_subj.transfer.img_id = data_subj.transfer.img_id(rand_idx_transfer,:);

data_subj.context.outcomes = cell2mat(cellfun(@(v) [v(:)' NaN(1, max(cellfun(@numel, {contexts.imgMean})) - numel(v))], {contexts.imgMean}', 'UniformOutput', false)); % Average value of options for each context (condi nb * option nb)
data_subj.context.variance = cell2mat(cellfun(@(v) [v(:)' NaN(1, max(cellfun(@numel, {contexts.imgVariance})) - numel(v))], {contexts.imgVariance}', 'UniformOutput', false)); % Variance of options for each context (condi nb * option nb)

%% Fixation data

all_cond = unique(sub_learning_data.cond_idx);
for cond = 1:numel(all_cond) % Create Dirichlet distribution for each option in each context across trials (for one participant)

    % Stimuli
    cond_stim_fix_ratio = sub_learning_data.stim_fix_ratio(sub_learning_data.cond_idx == all_cond(cond),:); % From worst to best option [min, mid, max]
    cond_stim_fix_ratio(:,end+1) = 1 - sum(cond_stim_fix_ratio,2); % Add the "other" fixations in the last column [min, mid, max, else]

    mu = mean(cond_stim_fix_ratio);
    sd = std(cond_stim_fix_ratio);
    alpha_dirich_stim(cond,:) = dirichlet_mle(mu, sd); % Get the Dirichlet parameters [min, mid, max, else]

    % Outcomes
    cond_out_fix_ratio = sub_learning_data.out_fix_ratio(sub_learning_data.cond_idx == all_cond(cond),:); % From worst to best option [min, mid, max]
    cond_out_fix_ratio(:,end+1) = 1 - sum(cond_out_fix_ratio,2); % Add the "other" fixations in the last column [min, mid, max, else]

    mu = mean(cond_out_fix_ratio);
    sd = std(cond_out_fix_ratio);
    alpha_dirich_out(cond,:) = dirichlet_mle(mu, sd); % Get the Dirichlet parameters [min, mid, max, else]

end % End of the loop through contexts

for trial = 1:numel(data_subj.learning.cond_idx) % Loop through learning trials

    trial_cond = data_subj.learning.cond_idx(trial); % Get context of the trial
    opt_nb = numel(data_subj.context.outcomes(abs(trial_cond),:)); % Get number of options in the context

    % Stimuli
    alpha_cond = alpha_dirich_stim(all_cond == trial_cond,:); % Get alphas for this context
    samp_fix = sample_dirichlet(alpha_cond); % Sample fixations data
    data_subj.learning.stim_fix_ratio(trial,:) = samp_fix(1:opt_nb); % From worst to best option [min, mid, max]

    % Outcomes
    alpha_cond = alpha_dirich_out(all_cond == trial_cond,:); % Get alphas for this context
    samp_fix = sample_dirichlet(alpha_cond); % Sample fixations data
    data_subj.learning.out_fix_ratio(trial,:) = samp_fix(1:opt_nb); % From worst to best option [min, mid, max]

end % End of the loop through learning trials

end
