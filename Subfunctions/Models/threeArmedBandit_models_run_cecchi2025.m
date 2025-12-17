%% THREE ARMED BANDIT
% -------------------------------------------------------
% Romane Cecchi, 2023
%
% INPUTS:
%   - params: vector or array (optimized by fmincon)
%   - data: structure with fields:
%       - learning.cond_idx: Condition index (1 to 4 ; negative = forced choice)
%       - learning.choice_rank: 1 = worst, 2 = middle, 3 = best choice
%       - learning.outcome: Outcome de l'option choisie
%       - learning.unchosen_out_max: Valeur de la meilleure option non choisie
%       - learning.unchosen_out_min: Valeur de la moins bonne option non choisie
%       - learning.img_id: Matrix similar to the Q-value matrix (condi * options (from worst to best)) with the corresponding image names
%       - learning.out_fix_ratio: Outcomes fixation time ratio (from worst to best option)
%       - transfer.img_id: Id of symbols presented during the trial
%       - transfer.choice_idx: Position of choice on screen
%       - context.outcomes: Average value of options for each context (condi nb * option nb)
%       - context.variance: Variance of options for each context (condi nb * option nb)
%   - model_info: model number OR structure with fields:
%       - model_info.idx = model number
%       - model_info.param = model parameters (obtained from 'del_models_param.m')
%   - modeling_step: 'fitting'|'simulation'
%   - phase_fit: 'learning'|'transfer'|'both'
%
% OUTPUTS:
%   - lik: Negative log likelihood (from fitting) -> Used by fmincon
%   - choice_proba: Structure with fields:
%       - learning: Probability of choosing each symbol (from worst to best)
%       - transfer_right_opt: Probability of choosing the option on the right in the transfer test
%   - Q: Q-value matrix (condi * options (worst to best))
%
% MODELS:
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

function [lik, out] = threeArmedBandit_models_run_cecchi2025(params, data, model_info, modeling_step, phase_fit)

% Parameters (optimized by fmincon when fitting)
beta          = params(1); % choice temperature
alpha         = params(2); % alpha (learning rate)
omega_100     = params(3); % omega 100
omega_50      = params(4); % omega 50
phi_att       = params(5); % phi (attentional)
epsilon       = params(6); % exploration rate
power_law_100 = params(7); % gamma 100
power_law_50  = params(8); % gamma 50
tau           = params(9); % choice trace learning/accumulation rate
phi_choice    = params(10); % choice trace decision bias

% Data
s  = data.learning.cond_idx; % State = Condition index (1 to 4 ; negative = forced choice)
ss = data.transfer.img_id; % Id of symbols presented during the trial

if ismember(modeling_step, {'fitting', 'prediction'}) % Model fitting

    a     = data.learning.choice_rank; % Choice rank: 1 = worst, 2 = middle, 3 = best choice (state action = real choice)
    r     = data.learning.outcome; % Outcome de l'option choisie (i.e., reward received)
    CFmax = data.learning.unchosen_out_max; % Valeur de la meilleure option non choisie
    CFmin = data.learning.unchosen_out_min; % Valeur de la moins bonne option non choisie
    aa    = data.transfer.choice_idx; % Position of choice on screen

elseif ismember(modeling_step, {'simulation'}) % Model simulation

    a = NaN(numel(s),1); % State action = Simulated choice
    r = NaN(numel(s),1); % Outcome de l'option choisie (i.e., reward received)
    CFmax = NaN(numel(s),1); % Valeur de la meilleure option non choisie
    CFmin = NaN(numel(s),1); % Valeur de la moins bonne option non choisie

end

nb_choice_opt = 3;
nb_condi = max(data.learning.cond_idx);

% Model_info can be a structure or a scalar
if isstruct(model_info)
    model_idx = model_info.idx;
else
    model_idx = model_info;
end

% Make 'phase_fit' an optional parameter (as we don't need it for the simulation step)
if ~exist('phase_fit','var')
    phase_fit = '';
end

% Model initialization
% Expected value (initialized to 41 if model without normalization and 0.5 otherwise) -> condi * options (worst to best)
if ismember(model_idx, [1 12 14])
    if contains(modeling_step, {'fitting', 'prediction'}) % Model fitting
        Q = zeros(nb_condi, nb_choice_opt) + round(mean([r, CFmin, CFmax], 'all')); % Mean of all options = 41
    elseif contains(modeling_step, {'simulation'}) % Model simulation
        Q = zeros(nb_condi, nb_choice_opt) + mean(data.context.outcomes, 'all');
    end
else
    Q = zeros(nb_condi, nb_choice_opt) + 1/2;
end

if model_idx == 14 % Choice perseveration (Katahira)
    C = zeros(nb_condi, nb_choice_opt); % C-traces
end

lik = 0; % Log-likelihood = log of a softmax function (==> Output needed by fmincon)

for t = 1:numel(s) % Loop through learning trials

    if ismember(modeling_step, {'simulation', 'prediction'}) % Model simulation (proba de choisir telle ou telle option)

        % Softmax decision rule

        if model_idx == 14 % Choice perseveration (Katahira)

            if s(t) > 0 % Free choice (100% ternary)

                PcMin = 1 / (1 + exp(((Q(s(t),2) - Q(s(t),1)) * beta) + ((C(s(t),2) - C(s(t),1)) * phi_choice)) + exp(((Q(s(t),3) - Q(s(t),1)) * beta) + ((C(s(t),3) - C(s(t),1)) * phi_choice))); % Probability of choosing the worst symbol
                PcMid = 1 / (1 + exp(((Q(s(t),1) - Q(s(t),2)) * beta) + ((C(s(t),1) - C(s(t),2)) * phi_choice)) + exp(((Q(s(t),3) - Q(s(t),2)) * beta) + ((C(s(t),3) - C(s(t),2)) * phi_choice))); % Probability of choosing the middle symbol
                PcMax = 1 / (1 + exp(((Q(s(t),1) - Q(s(t),3)) * beta) + ((C(s(t),1) - C(s(t),3)) * phi_choice)) + exp(((Q(s(t),2) - Q(s(t),3)) * beta) + ((C(s(t),2) - C(s(t),3)) * phi_choice))); % Probability of choosing the best symbol

            elseif s(t) < 0 % Forced choice between worst and middle options

                PcMin = 1 / (1 + exp(((Q(abs(s(t)),2) - Q(abs(s(t)),1)) * beta) + ((C(abs(s(t)),2) - C(abs(s(t)),1)) * phi_choice))); % Probability of choosing the worst symbol
                PcMid = 1 / (1 + exp(((Q(abs(s(t)),1) - Q(abs(s(t)),2)) * beta) + ((C(abs(s(t)),1) - C(abs(s(t)),2)) * phi_choice))); % Probability of choosing the middle symbol
                PcMax = NaN; % Probability of choosing the best symbol

            end

        else % All other models

            if s(t) > 0 % Free choice (100% ternary)

                PcMin = 1 / (1 + exp((Q(s(t),2) - Q(s(t),1)) * beta) + exp((Q(s(t),3) - Q(s(t),1)) * beta)); % Probability of choosing the worst symbol
                PcMid = 1 / (1 + exp((Q(s(t),1) - Q(s(t),2)) * beta) + exp((Q(s(t),3) - Q(s(t),2)) * beta)); % Probability of choosing the middle symbol
                PcMax = 1 / (1 + exp((Q(s(t),1) - Q(s(t),3)) * beta) + exp((Q(s(t),2) - Q(s(t),3)) * beta)); % Probability of choosing the best symbol

            elseif s(t) < 0 % Forced choice between worst and middle options

                PcMin =  1 / (1 + exp((Q(abs(s(t)),2) - Q(abs(s(t)),1)) * beta)); % Probability of choosing the worst symbol
                PcMid =  1 / (1 + exp((Q(abs(s(t)),1) - Q(abs(s(t)),2)) * beta)); % Probability of choosing the middle symbol
                PcMax =  NaN; % Probability of choosing the best symbol

            end

        end

        proba = [PcMin PcMid PcMax]; % Probas (1 = min, 2 = mid, 3 = max)

        if ismember(modeling_step, {'simulation'})

            % Make the choice based on the probability of choosing each symbol
            choice_opt = [1 2 3]; % Choice options (1 = min, 2 = mid, 3 = max)

            a(t) = choice_opt(find(rand < cumsum(proba), 1, 'first')); % Select a symbol with its probability

        end

        choice_proba.learning(t,:) = proba; % Probability of choosing each symbol (from worst to best)

    end % End of modeling step condition

    if isempty(a(t)), disp('error'); end % Sanity check

    % Get Q-values -------------------------------------------------- %

    out.Q_time(:,:,t) = Q;

    Q_chosen = Q(abs(s(t)), a(t)); % State-action value

    unchosen_idx = 1:nb_choice_opt;
    unchosen_idx = unchosen_idx(unchosen_idx ~= a(t)); % Indexes of unchosen options

    Q_unchosen_min = Q(abs(s(t)), min(unchosen_idx));
    Q_unchosen_max = Q(abs(s(t)), max(unchosen_idx));

    if s(t) > 0 % Free choice (100% ternary)
        Q_all = Q(s(t),:); % Q-values of all options of the condition
    else % Forced choice between options 1 (= worst) and 2 (= middle option)
        Q_all = Q(abs(s(t)), 1:2);
        if a(t) == 3, disp('error'); end % Sanity check
    end

    if model_idx == 14 % Choice perseveration (Katahira)

        out.C_trace(:,:,t) = C;

        if s(t) > 0 % Free choice (100% ternary)
            C_all = C(s(t),:); % C-values of all options of the condition
        else % Forced choice between options 1 (= worst) and 2 (= middle option)
            C_all = C(abs(s(t)), 1:2);
        end

        C_chosen = C(abs(s(t)), a(t));
        C_unchosen_min = C(abs(s(t)), min(unchosen_idx));
        C_unchosen_max = C(abs(s(t)), max(unchosen_idx));

    end

    % --------------------------------------------------------------- %

    if ismember(modeling_step, {'fitting'}) % Model fitting (compute LL)
        if ismember(phase_fit, {'learning', 'both'}) && ~isnan(a(t)) % Fit including learning phase

            if model_idx == 14 % Choice perseveration (Katahira)

                % Log-likelihood function: sum over trials of the log of the choice probability (i.e., softmax function)
                log_prob = (beta * Q_chosen) + (phi_choice * C_chosen) - log(sum(exp(beta * Q_all + phi_choice * C_all)));
                lik = lik + log_prob;

            else % All other models

                % Log-likelihood function: sum over trials of the log of the choice probability (i.e., softmax function)
                lik = lik + (beta * Q_chosen - log(sum(exp(beta * Q_all))));

            end

        end
    end % End of modeling step condition

    %% Learning steps

    bestIsClickable = s(t) > 0;
    s(t) = abs(s(t));

    if ismember(modeling_step, {'simulation'}) % Model simulation

        % For each trial, set the reward behind each symbol
        mean_out = data.context.outcomes(s(t),:);
        var_out = data.context.variance(s(t),:);
        outcomes = round(normrnd(mean_out, var_out));

        % Constrain outcomes from 0 to 100
        outcomes(outcomes > 100) = 100;
        outcomes(outcomes < 0) = 0;

        % Define outcomes
        r(t)     = outcomes(a(t));
        CFmin(t) = outcomes(min(unchosen_idx));
        CFmax(t) = outcomes(max(unchosen_idx));

    end

    % Update values with reward

    all_opt_val = [r(t), CFmin(t), CFmax(t)]; % Outcomes of all options

    if model_idx == 1 % Qlearning 1 alpha

        deltaF    = r(t)     - Q_chosen;       % Prediction error of the chosen option (factual)
        deltaCmin = CFmin(t) - Q_unchosen_min; % Prediction error of min unchosen option (counterfactual)
        deltaCmax = CFmax(t) - Q_unchosen_max; % Prediction error of max unchosen option

        Q(s(t), a(t))              = Q_chosen       + alpha * deltaF;    % Update Q-value of chosen option
        Q(s(t), min(unchosen_idx)) = Q_unchosen_min + alpha * deltaCmin; % Update Q-value of min unchosen option
        Q(s(t), max(unchosen_idx)) = Q_unchosen_max + alpha * deltaCmax; % Update Q-value of max unchosen option

    elseif model_idx == 2 % RANGE 1 alpha 2 omega -> One omega by attentional condition (100/50)

        if ismember(s(t), [1,3])
            norm_r     = ((r(t)     - min(all_opt_val)) / (max(all_opt_val) - min(all_opt_val)))^omega_100;
            norm_CFmin = ((CFmin(t) - min(all_opt_val)) / (max(all_opt_val) - min(all_opt_val)))^omega_100;
            norm_CFmax = ((CFmax(t) - min(all_opt_val)) / (max(all_opt_val) - min(all_opt_val)))^omega_100;
        elseif ismember(s(t), [2,4])
            norm_r     = ((r(t)     - min(all_opt_val)) / (max(all_opt_val) - min(all_opt_val)))^omega_50;
            norm_CFmin = ((CFmin(t) - min(all_opt_val)) / (max(all_opt_val) - min(all_opt_val)))^omega_50;
            norm_CFmax = ((CFmax(t) - min(all_opt_val)) / (max(all_opt_val) - min(all_opt_val)))^omega_50;
        end

        deltaF    = norm_r     - Q_chosen;
        deltaCmin = norm_CFmin - Q_unchosen_min;
        deltaCmax = norm_CFmax - Q_unchosen_max;

        Q(s(t), a(t))              = Q_chosen       + alpha * deltaF;    % Update Q-value of chosen option
        Q(s(t), min(unchosen_idx)) = Q_unchosen_min + alpha * deltaCmin; % Update Q-value of min unchosen option
        Q(s(t), max(unchosen_idx)) = Q_unchosen_max + alpha * deltaCmax; % Update Q-value of max unchosen option

    elseif ismember(model_idx, [3,4,5,9,10,11,15,16]) % EYE RANGE 1 alpha (stim fix AND/OR out fix)

        switch model_idx

            case {3,9} % Weighted sum of STIM and OUT fixation ratios ------- %

                fix_r     = phi_att * data.learning.stim_fix_ratio(t, a(t)) + (1 - phi_att) * data.learning.out_fix_ratio(t, a(t));
                fix_CFmin = phi_att * data.learning.stim_fix_ratio(t, min(unchosen_idx)) + (1 - phi_att) * data.learning.out_fix_ratio(t, min(unchosen_idx));
                fix_CFmax = phi_att * data.learning.stim_fix_ratio(t, max(unchosen_idx)) + (1 - phi_att) * data.learning.out_fix_ratio(t, max(unchosen_idx));

            case {4,10} % Raw fixation ratios STIM --------------------------- %

                fix_r     = data.learning.stim_fix_ratio(t, a(t));
                fix_CFmin = data.learning.stim_fix_ratio(t, min(unchosen_idx));
                fix_CFmax = data.learning.stim_fix_ratio(t, max(unchosen_idx));

            case {5,11} % Raw fixation ratios OUT ---------------------------- %

                fix_r     = data.learning.out_fix_ratio(t, a(t));
                fix_CFmin = data.learning.out_fix_ratio(t, min(unchosen_idx));
                fix_CFmax = data.learning.out_fix_ratio(t, max(unchosen_idx));

            case 15 % GRID SEARCH option -------------------------------- %

                % Take only the X first seconds of fixation

                if ismember(data.time, {'ms'})

                    size_stim = numel(data.learning.stim_fix_course{t, 1});
                    size_out = numel(data.learning.out_fix_course{t, 1});

                    if data.fixTimeStim > size_stim
                        data.fixTimeStim = size_stim;
                    end

                    if data.fixTimeOut > size_out
                        data.fixTimeOut = size_out;
                    end

                end

                if ismember(data.time, {'ms'}) % Time in ms

                    % Stimuli (BACKWARD from choice to stimulus onset)
                    stim_fix_r     = data.learning.stim_fix_course{t, a(t)}(end-data.fixTimeStim+1:end);
                    stim_fix_CFmin = data.learning.stim_fix_course{t, min(unchosen_idx)}(end-data.fixTimeStim+1:end);
                    stim_fix_CFmax = data.learning.stim_fix_course{t, max(unchosen_idx)}(end-data.fixTimeStim+1:end);

                    % Outcomes (FORWARD from outcome onset to outcome offset)
                    out_fix_r     = data.learning.out_fix_course{t, a(t)}(1:data.fixTimeOut);
                    out_fix_CFmin = data.learning.out_fix_course{t, min(unchosen_idx)}(1:data.fixTimeOut);
                    out_fix_CFmax = data.learning.out_fix_course{t, max(unchosen_idx)}(1:data.fixTimeOut);

                elseif ismember(data.time, {'prct'}) % Percent of trial

                    emptyTime = {0,0,0};

                    % Stimuli (BACKWARD from choice to stimulus onset)
                    ntime = ceil(size(data.learning.stim_fix_course{t, 1},2) * (data.fixTimeStim/100));

                    if ntime ~= 0
                        stim_fix_r     = data.learning.stim_fix_course{t, a(t)}(end-ntime+1:end);
                        stim_fix_CFmin = data.learning.stim_fix_course{t, min(unchosen_idx)}(end-ntime+1:end);
                        stim_fix_CFmax = data.learning.stim_fix_course{t, max(unchosen_idx)}(end-ntime+1:end);
                    else
                        [stim_fix_r, stim_fix_CFmin, stim_fix_CFmax] = emptyTime{:};
                    end

                    % Outcomes (FORWARD from outcome onset to outcome offset)
                    ntime = ceil(size(data.learning.out_fix_course{t, 1},2) * (data.fixTimeOut/100));

                    if ntime ~= 0
                        out_fix_r     = data.learning.out_fix_course{t, a(t)}(1:ntime);
                        out_fix_CFmin = data.learning.out_fix_course{t, min(unchosen_idx)}(1:ntime);
                        out_fix_CFmax = data.learning.out_fix_course{t, max(unchosen_idx)}(1:ntime);
                    else
                        [out_fix_r, out_fix_CFmin, out_fix_CFmax] = emptyTime{:};
                    end

                end

                % ------------------------------------------------------- %

                % Raw fixation ratios STIM + OUT
                fix_r     = mean([stim_fix_r out_fix_r], 'omitnan');
                fix_CFmin = mean([stim_fix_CFmin out_fix_CFmin], 'omitnan');
                fix_CFmax = mean([stim_fix_CFmax out_fix_CFmax], 'omitnan');

            case 16 % SLIDING WINDOW option ----------------------------- %

                if ismember(data.time, {'prct'}) % Percent of trial

                    if data.fixTimeOut == 0 % If no outcomes

                        % Stimuli
                        ntime = ceil(size(data.learning.stim_fix_course{t, 1},2) * (data.fixTimeStim/100));
                        fix_course = data.learning.stim_fix_course;

                    elseif data.fixTimeStim == 0 % If no stimuli

                        % Outcomes
                        ntime = ceil(size(data.learning.out_fix_course{t, 1},2) * (data.fixTimeOut/100));
                        fix_course = data.learning.out_fix_course;

                    end

                    ntime(ntime == 0) = 1; % Replace 0 by 1 (because time 0 doesn't exist)

                    fix_r     = mean(fix_course{t, a(t)}(ntime(1):ntime(2)), 'omitnan');
                    fix_CFmin = mean(fix_course{t, min(unchosen_idx)}(ntime(1):ntime(2)), 'omitnan');
                    fix_CFmax = mean(fix_course{t, max(unchosen_idx)}(ntime(1):ntime(2)), 'omitnan');

                end

        end % End of switch model_idx

        % --------------------------------------------------------------- %

        switch model_idx

            case {3,4,5,15,16}

                % Apply the effect of fixation on the outcome value BEFORE normalization of values

                norm_r     = r(t) * fix_r;
                norm_CFmin = CFmin(t) * fix_CFmin;
                norm_CFmax = CFmax(t) * fix_CFmax;

                range_norm_fun = @(val, range) (val - min(range)) / (max(range) - min(range));
                all_opt_val = [norm_r norm_CFmin norm_CFmax];

                if all(all_opt_val == 0) || all(all_opt_val == 1) % Otherwise, it will result in NaN
                    att_r     = 0;
                    att_CFmin = 0;
                    att_CFmax = 0;
                else
                    att_r     = range_norm_fun(norm_r, all_opt_val);
                    att_CFmin = range_norm_fun(norm_CFmin, all_opt_val);
                    att_CFmax = range_norm_fun(norm_CFmax, all_opt_val);
                end

            case {9,10,11}

                % Apply the effect of fixation on the outcome value AFTER normalization of values

                range_norm_fun = @(val, range) (val - min(range)) / (max(range) - min(range));
                all_opt_val = [r(t) CFmin(t) CFmax(t)];

                norm_r     = range_norm_fun(r(t), all_opt_val);
                norm_CFmin = range_norm_fun(CFmin(t), all_opt_val);
                norm_CFmax = range_norm_fun(CFmax(t), all_opt_val);

                att_r = norm_r * fix_r;
                att_CFmin = norm_CFmin * fix_CFmin;
                att_CFmax = norm_CFmax * fix_CFmax;

        end

        % --------------------------------------------------------------- %

        deltaF    = att_r     - Q_chosen;
        deltaCmin = att_CFmin - Q_unchosen_min;
        deltaCmax = att_CFmax - Q_unchosen_max;

        Q(s(t), a(t))              = Q_chosen       + alpha * deltaF;    % Update Q-value of chosen option
        Q(s(t), min(unchosen_idx)) = Q_unchosen_min + alpha * deltaCmin; % Update Q-value of min unchosen option

        if bestIsClickable % Update the Q-value of the best option in the forced condition only if it was clickable
            Q(s(t), max(unchosen_idx)) = Q_unchosen_max + alpha * deltaCmax; % Update Q-value of max unchosen option
        end

    elseif ismember(model_idx, [6,7,8]) % EYE NO VALUE

        switch model_idx

            case 6 % Weighted sum of STIM and OUT fixation ratios ------- %

                att_r     = phi_att * data.learning.stim_fix_ratio(t, a(t)) + (1 - phi_att) * data.learning.out_fix_ratio(t, a(t));
                att_CFmin = phi_att * data.learning.stim_fix_ratio(t, min(unchosen_idx)) + (1 - phi_att) * data.learning.out_fix_ratio(t, min(unchosen_idx));
                att_CFmax = phi_att * data.learning.stim_fix_ratio(t, max(unchosen_idx)) + (1 - phi_att) * data.learning.out_fix_ratio(t, max(unchosen_idx));

            case 7 % Raw fixation ratios STIM --------------------------- %

                att_r     = data.learning.stim_fix_ratio(t, a(t));
                att_CFmin = data.learning.stim_fix_ratio(t, min(unchosen_idx));
                att_CFmax = data.learning.stim_fix_ratio(t, max(unchosen_idx));

            case 8 % Raw fixation ratios OUT ---------------------------- %

                att_r     = data.learning.out_fix_ratio(t, a(t));
                att_CFmin = data.learning.out_fix_ratio(t, min(unchosen_idx));
                att_CFmax = data.learning.out_fix_ratio(t, max(unchosen_idx));

        end

        deltaF    = att_r     - Q_chosen;
        deltaCmin = att_CFmin - Q_unchosen_min;
        deltaCmax = att_CFmax - Q_unchosen_max;

        Q(s(t), a(t))              = Q_chosen       + alpha * deltaF;    % Update Q-value of chosen option
        Q(s(t), min(unchosen_idx)) = Q_unchosen_min + alpha * deltaCmin; % Update Q-value of min unchosen option

        if bestIsClickable
            Q(s(t), max(unchosen_idx)) = Q_unchosen_max + alpha * deltaCmax; % Update Q-value of max unchosen option
        end

    elseif model_idx == 12 % Power-law compression

        if ismember(s(t), [1,3])
            subj_r     = r(t)^power_law_100;
            subj_CFmin = CFmin(t)^power_law_100;
            subj_CFmax = CFmax(t)^power_law_100;
        elseif ismember(s(t), [2,4])
            subj_r     = r(t)^power_law_50;
            subj_CFmin = CFmin(t)^power_law_50;
            subj_CFmax = CFmax(t)^power_law_50;
        end

        deltaF    = subj_r     - Q_chosen;       % Prediction error of the chosen option (factual)
        deltaCmin = subj_CFmin - Q_unchosen_min; % Prediction error of min unchosen option (counterfactual)
        deltaCmax = subj_CFmax - Q_unchosen_max; % Prediction error of max unchosen option

        Q(s(t), a(t))              = Q_chosen       + alpha * deltaF;    % Update Q-value of chosen option
        Q(s(t), min(unchosen_idx)) = Q_unchosen_min + alpha * deltaCmin; % Update Q-value of min unchosen option
        Q(s(t), max(unchosen_idx)) = Q_unchosen_max + alpha * deltaCmax; % Update Q-value of max unchosen option

    elseif model_idx == 13 % RANGE 1 alpha 1 epsilon [Argmax + Epsilon-greedy in transfer]

        norm_r     = (r(t)     - min(all_opt_val)) / (max(all_opt_val) - min(all_opt_val));
        norm_CFmin = (CFmin(t) - min(all_opt_val)) / (max(all_opt_val) - min(all_opt_val));
        norm_CFmax = (CFmax(t) - min(all_opt_val)) / (max(all_opt_val) - min(all_opt_val));

        deltaF    = norm_r     - Q_chosen;
        deltaCmin = norm_CFmin - Q_unchosen_min;
        deltaCmax = norm_CFmax - Q_unchosen_max;

        Q(s(t), a(t))              = Q_chosen       + alpha * deltaF;    % Update Q-value of chosen option
        Q(s(t), min(unchosen_idx)) = Q_unchosen_min + alpha * deltaCmin; % Update Q-value of min unchosen option
        Q(s(t), max(unchosen_idx)) = Q_unchosen_max + alpha * deltaCmax; % Update Q-value of max unchosen option

    elseif model_idx == 14 % Choice perseveration (Katahira)

        norm_r     = r(t);
        norm_CFmin = CFmin(t);
        norm_CFmax = CFmax(t);

        deltaF    = norm_r     - Q_chosen;       % Prediction error of the chosen option (factual)
        deltaCmin = norm_CFmin - Q_unchosen_min; % Prediction error of min unchosen option (counterfactual)
        deltaCmax = norm_CFmax - Q_unchosen_max; % Prediction error of max unchosen option

        Q(s(t), a(t))              = Q_chosen       + alpha * deltaF;    % Update Q-value of chosen option
        Q(s(t), min(unchosen_idx)) = Q_unchosen_min + alpha * deltaCmin; % Update Q-value of min unchosen option
        Q(s(t), max(unchosen_idx)) = Q_unchosen_max + alpha * deltaCmax; % Update Q-value of max unchosen option

        C(s(t), a(t))              = C_chosen       + tau * (1 - C_chosen); % Update C-value of chosen option
        C(s(t), min(unchosen_idx)) = C_unchosen_min + tau * (0 - C_unchosen_min); % Update C-value of min unchosen option
        C(s(t), max(unchosen_idx)) = C_unchosen_max + tau * (0 - C_unchosen_max); % Update C-value of max unchosen option

    end % End of model definition
end % End of the loop through learning trials

%% Transfer Test

for tt = 1:length(ss) % Loop through transfer trials

    if (ismember(modeling_step, {'fitting'}) && ismember(phase_fit, {'transfer', 'both'}) && ~isnan(aa(tt))) || ... % Model fitting & Fit including the transfer
            (ismember(modeling_step, {'prediction'})) % Model prediction

        % In the transfer: only 2 options are presented
        chosen_img_idx   = ss(tt, aa(tt));
        unchosen_img_idx = ss(tt, ss(tt,:) ~= chosen_img_idx & ~isnan(ss(tt,:)));

        [rowF,  colF]  = find(chosen_img_idx   == data.learning.img_id); % Find the position of the option in the matrix
        [rowCF, colCF] = find(unchosen_img_idx == data.learning.img_id);

        Q_chosen   = Q(rowF, colF);
        Q_unchosen = Q(rowCF, colCF);
        Q_all      = [Q_chosen, Q_unchosen];

        if model_idx == 14 % Choice perseveration (Katahira)

            C_chosen = C(rowF, colF);
            C_unchosen = C(rowCF, colCF);
            C_all = [C_chosen, C_unchosen];

            log_prob = (beta * Q_chosen) + (phi_choice * C_chosen) - log(sum(exp(beta * Q_all + phi_choice * C_all)));
            lik = lik + log_prob;

            if ismember(modeling_step, {'prediction'})
                choice_proba.transfer_chosen_opt(tt,:) = 1 / (1 + exp(((Q_unchosen - Q_chosen) * beta) + ((C_unchosen - C_chosen) * phi_choice))); % Proba de choisir l'option réellement choisie
            end

            % Update C-traces
            C(rowF, colF)   = C_chosen   + tau * (1 - C_chosen); % Update C-value of chosen option
            C(rowCF, colCF) = C_unchosen + tau * (0 - C_unchosen); % Update C-value of unchosen option

        elseif model_idx == 13 % RANGE 1 alpha 1 epsilon [Argmax + Epsilon-greedy in transfer]

            % Greedy indicator: 1 if chosen option is the argmax; 0 otherwise
            is_greedy = (Q_chosen > Q_unchosen);

            % Compute probability of choosing the actually chosen option
            % p = (1 - ε) if greedy; ε if non-greedy
            p_chosen = (1 - epsilon) * is_greedy + epsilon * (~is_greedy);

            % Tie override: if values tie, probability is exactly 0.5 regardless of ε
            if Q_chosen == Q_unchosen
                p_chosen = 0.5;
            end

            if ismember(modeling_step, {'prediction'})
                choice_proba.transfer_chosen_opt(tt,:) = p_chosen; % Proba de choisir l'option réellement choisie
            end

            lik = lik + log(p_chosen);

        else % All other models

            lik = lik + (beta * Q_chosen - log(sum(exp(beta * Q_all))));

            if ismember(modeling_step, {'prediction'})
                choice_proba.transfer_chosen_opt(tt,:) = 1 / (1 + exp((Q_unchosen - Q_chosen) * beta)); % Proba de choisir l'option réellement choisie
            end

        end

    elseif ismember(modeling_step, {'simulation'}) % Model simulation

        [rowL, colL] = find(ss(tt,1) == data.learning.img_id); % Find the position of the left option in the matrix
        [rowR, colR] = find(ss(tt,2) == data.learning.img_id); % Find the position of the right option in the matrix

        Q_left  = Q(rowL, colL);
        Q_right = Q(rowR, colR);

        if model_idx == 14 % Choice perseveration (Katahira)

            C_left  = C(rowL, colL);
            C_right = C(rowR, colR);

            choice_proba.transfer_left_opt(tt,:) = 1 / (1 + exp(((Q_right - Q_left) * beta) + ((C_right - C_left) * phi_choice))); % Proba de choisir l'option de gauche

        elseif model_idx == 13 % RANGE 1 alpha 1 epsilon [Argmax + Epsilon-greedy in transfer]

            epsilon = tau; % Epsilon for epsilon-greedy (exploration rate)

            % Greedy indicator: 1 if left option is the argmax; 0 otherwise
            is_greedy = (Q_left > Q_right);

            % Compute probability of choosing the left option
            % p = (1 - ε) if greedy; ε if non-greedy
            p_left = (1 - epsilon) * is_greedy + epsilon * (~is_greedy);

            % Tie override: if values tie, probability is exactly 0.5 regardless of ε
            if Q_left == Q_right
                p_left = 0.5;
            end

            choice_proba.transfer_left_opt(tt,:) = p_left; % Proba de choisir l'option de gauche

        else % All other models
            choice_proba.transfer_left_opt(tt,:) = 1 / (1 + exp((Q_right - Q_left) * beta)); % Proba de choisir l'option de gauche
        end

        % Make a choice based on the probability of choosing each symbol
        choice_opt = [1 2]; % Choice options (1 = left, 2 = right)
        proba = [choice_proba.transfer_left_opt(tt,:) 1-choice_proba.transfer_left_opt(tt,:)];
        aa(tt,:) = choice_opt(find(rand < cumsum(proba), 1, 'first')); % Select a symbol with its probability (randsample(choice_opt, 1, true, proba) can also be used)

        if model_idx == 14 % Choice perseveration (Katahira)

            if aa(tt,:) == 1 % Choice = left
                C(rowL, colL) = C_left  + tau * (1 - C_left); % Update C-value of chosen option
                C(rowR, colR) = C_right + tau * (0 - C_right); % Update C-value of unchosen option
            elseif aa(tt,:) == 2 % Choice = right
                C(rowR, colR) = C_right + tau * (1 - C_right); % Update C-value of chosen option
                C(rowL, colL) = C_left  + tau * (0 - C_left); % Update C-value of unchosen option
            end

        end

    end

end % End of the loop through transfer trials

%% End of task steps

lik = -lik; % Must be inverted as fmincon searches for the minimum value

%% Prior penalization
% See Daw et al., 2011 - Model-based influences on humans' choices and striatal prediction errors
% Gershman, 2016 - Empirical priors for reinforcement learning models

if ismember(modeling_step, {'fitting'}) % Model fitting

    count = 0;
    model_param = model_info.param;
    p = NaN(1,sum(model_param.idx));

    for i = find(model_param.idx)
        count = count + 1;
        switch model_param.names{i}
            case {'beta', 'omega_100', 'omega_50'}
                p(count) = log(gampdf(params(i),1.2,5));
            case {'alpha', 'phi_att', 'power_law_100', 'power_law_50', 'epsilon', 'tau'}
                p(count) = log(betapdf(params(i),1.1,1.1)); % The beta probability density function is bounded (compared to the gamma one)
            case {'phi_choice'}
                p(count) = log(normpdf(params(i),0,1));
        end
    end

    p = -sum(p);

    lik = p + lik;

end

%% Output

if ismember(modeling_step, {'simulation', 'prediction'})
    out.choice_proba = choice_proba;
end

out.Q_final = Q;

if ismember(modeling_step, {'simulation'})
    out.data.learning.choice_rank = a;
    out.data.learning.outcome = r;
    out.data.learning.unchosen_out_max = CFmax;
    out.data.learning.unchosen_out_min = CFmin;
    out.data.transfer.choice_idx = aa;
end

end
