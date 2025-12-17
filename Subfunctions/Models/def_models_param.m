% OUTPUTS :
% - param.lower_bounds
% - param.upper_bounds
% - param.initial_point
% - param.nfpm (number of free parameters)

% MODELS:
% 1: Q-LEARNING 1 alpha (= no normalization = Qvalue from 0 to 100)
% 2: RANGE 1 alpha 2 omega -> 1 omega by attentional condition (100/50)
% 3: EYE RANGE 1 alpha + 1 phi (weighted sum of stim and out fix)
% 4: EYE RANGE 1 alpha (stim fix only)
% 5: EYE RANGE 1 alpha (out fix only)
% 6: EYE only 1 alpha + 1 phi (weighted sum of stim and out fix)
% 7: EYE only 1 alpha (stim fix only)
% 8: EYE only 1 alpha (out fix only)
% 9:  RANGE EYE 1 alpha + 1 phi (weighted sum of stim and out fix)
% 10: RANGE EYE 1 alpha (stim fix only)
% 11: RANGE EYE 1 alpha (out fix only)
% 12: Power-law compression
% 13: RANGE 1 alpha 1 epsilon [Range + Argmax + Epsilon-greedy in transfer]
% 14: Choice perseveration (Katahira)
% 15: model_fitting_incremental_window.m
% 16: model_fitting_discrete_window.m

function param = def_models_param(model_idx)

param.names = {'beta', 'alpha', 'omega_100', 'omega_50', 'phi_att', 'epsilon', 'power_law_100', 'power_law_50', 'tau', 'phi_choice'};

param.lower_bounds = zeros(1,numel(param.names));

switch model_idx
    case {1,4,5,7,8,10,11,15,16}
        param.initial_point = [1 .5 NaN NaN NaN NaN NaN NaN NaN NaN];
        param.upper_bounds = [Inf 1 NaN NaN NaN NaN NaN NaN NaN NaN];
    case {2}
        param.initial_point = [1 .5 1 1 NaN NaN NaN NaN NaN NaN];
        param.upper_bounds = [Inf 1 Inf Inf NaN NaN NaN NaN NaN NaN];
    case {3,6,9}
        param.initial_point = [1 .5 NaN NaN .5 NaN NaN NaN NaN NaN];
        param.upper_bounds = [Inf 1 NaN NaN 1 NaN NaN NaN NaN NaN];
    case {12}
        param.initial_point = [1 .5 NaN NaN NaN NaN .5 .5 NaN NaN];
        param.upper_bounds = [Inf 1 NaN NaN NaN NaN 1 1 NaN NaN];
    case {13}
        param.initial_point = [1 .5 NaN NaN NaN .5 NaN NaN NaN NaN];
        param.upper_bounds = [Inf 1 NaN NaN NaN 1 NaN NaN NaN NaN];
    case {14}
        param.initial_point = [1 .5 NaN NaN NaN NaN NaN NaN .5 0];
        param.upper_bounds = [Inf 1 NaN NaN NaN NaN NaN NaN 1 Inf];
        param.lower_bounds = [0 0 0 0 0 0 0 0 0 -Inf];
end

%% Position of "active" parameters

param.idx = ~isnan(param.initial_point);

%% Number of free parameters

param.nfpm = sum(param.idx);

%% Replace NaN with 0 (for fmincon)

param.initial_point(isnan(param.initial_point)) = 0;
param.upper_bounds(isnan(param.upper_bounds)) = 0;

end