function [learning_choice_proba, transfer_choice_proba] = sim_learning_and_transfer_phases(data_subj, choice_proba)

% Recreate learning phase ----------------------------------- %
for condi = 1:max(abs(data_subj.learning.cond_idx))

    condi_trial_ternary = ismember(data_subj.learning.cond_idx, condi);
    condi_trial_binary = ismember(data_subj.learning.cond_idx, -condi); % /!\ for now, only work for "forced" task

    learning_choice_proba(condi,:,1) = mean(choice_proba.learning(condi_trial_ternary,:)); % condi * option (from worst to best)
    learning_choice_proba(condi,:,2) = mean(choice_proba.learning(condi_trial_binary,:));

end

% Recreate the transfer test -------------------------------- %
counter = zeros(size(data_subj.learning.img_id)); % Count the number of times each option is presented
transfer_cProba = cell(size(data_subj.learning.img_id));

for tt = 1:length(data_subj.transfer.img_id) % Loop through transfer trials

    [rowL, colL] = find(data_subj.transfer.img_id(tt,1) == data_subj.learning.img_id); % Find the position of the left option in the matrix
    [rowR, colR] = find(data_subj.transfer.img_id(tt,2) == data_subj.learning.img_id); % Find the position of the right option in the matrix

    counter(rowL, colL) = counter(rowL, colL) + 1;
    counter(rowR, colR) = counter(rowR, colR) + 1;

    % Make the choice based on the probability of choosing each symbol
    choice_opt = {'L', 'R'}; % Choice options (1 = left, 2 = right)
    proba      = [choice_proba.transfer_left_opt(tt), 1 - choice_proba.transfer_left_opt(tt)]; % Probas
    choice     = choice_opt{find(rand < cumsum(proba), 1, 'first')}; % Select a symbol with its probability

    if strcmp(choice, 'L')
        transfer_cProba{rowL, colL}(counter(rowL, colL)) = 1;
        transfer_cProba{rowR, colR}(counter(rowR, colR)) = 0;
    elseif strcmp(choice, 'R')
        transfer_cProba{rowL, colL}(counter(rowL, colL)) = 0;
        transfer_cProba{rowR, colR}(counter(rowR, colR)) = 1;
    end

end

transfer_choice_proba = cellfun(@mean, transfer_cProba); % condi * option (from worst to best) * subject * repetition

end