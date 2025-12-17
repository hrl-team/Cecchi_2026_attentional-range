%   
% This function extracts the selected participant's trials from the experiment database, computes
% key learning/transfer variables (e.g., chosen outcome, unchosen extrema, choice rank), and adds
% eye-tracking fixation summaries aligned with learning trials. Outputs are organised in the
% structure `data_subj` with two main subfields: `learning` and `transfer`.
%
% INPUTS
%   opt            Struct of analysis options. Must contain:
%                    - opt.task : task identifier string used to determine forced-choice coding.
%                                Supported in this code path:
%                                  * 'e1_forced'
%                                  * 'e2_lum_stim'
%                                  * 'e3_lum_out'
%
%   db             Struct containing the experimental dataset, expected to include at least:
%                    - db.header : participant/session header table/struct array. The function uses
%                                  db.header.id(sub) and db.header(sub,:) to retrieve the current
%                                  participant id and context header.
%                    - db.expe   : trial-level table containing behavioural variables. The function
%                                  expects (at minimum) the following fields:
%                                    * id                 : participant id per trial
%                                    * phase              : 'learning' or 'transfer'
%                                    * condi_id           : condition index (0-based in raw data)
%                                    * stim_is_clickable  : cell array indicating clickability per stimulus
%                                    * stim_id            : cell array of stimulus ids presented
%                                    * stim_outcomes      : cell array of outcomes for presented stimuli
%                                    * choice_outcome     : outcome value of the chosen option
%                                    * choice_screen_idx  : 0-based index of chosen option position on screen
%
%   sub            Scalar index selecting the participant in db.header (row index into db.header).
%
%   eye_data_stim  Table containing stimulus-related eye-tracking metrics per participant/trial.
%                  Must include:
%                    - id              : participant id (to match db.header.id(sub))
%                    - fix_time_ratio  : fixation time ratio per option (ordered worst -> best)
%                    - fix_time_course : fixation time course per option (ordered worst -> best)
%
%   eye_data_out   Table containing outcome-related eye-tracking metrics per participant/trial.
%                  Must include:
%                    - id              : participant id (to match db.header.id(sub))
%                    - fix_time_ratio  : fixation time ratio per option (ordered worst -> best)
%                    - fix_time_course : fixation time course per option (ordered worst -> best)
%
% OUTPUT
%   data_subj      Struct with fields:
%
%     data_subj.learning
%       .cond_idx         Condition index for learning trials, coded as:
%                           - values 1..4 for non-forced trials (derived from condi_id + 1)
%                           - negative values indicate forced choice (same magnitude as above)
%       .outcome          Outcome value of the chosen option on each learning trial.
%       .unchosen_out_max Maximum outcome among the unchosen options on each learning trial.
%       .unchosen_out_min Minimum outcome among the unchosen options on each learning trial.
%       .choice_rank      Rank of the chosen outcome among presented options:
%                           1 = worst choice, 2 = middle choice, 3 = best choice.
%       .img_id           Matrix mapping each context (row) to stimulus numeric ids (columns),
%                         ordered from worst to best option within each context. Size:
%                           [nContexts x maxNbOptionsAcrossContexts]
%       .out_fix_ratio    Outcome-screen fixation time ratio per option (worst -> best).
%       .out_fix_course   Outcome-screen fixation time course per option (worst -> best).
%                         Convention: 0 = not looked; 1 = looked; 1000 pts = 1 second.
%       .stim_fix_ratio   Stimulus-screen fixation time ratio per option (worst -> best).
%       .stim_fix_course  Stimulus-screen fixation time course per option (worst -> best).
%                         Convention: 0 = not looked; 1 = looked; 1000 pts = 1 second.
%
%     data_subj.transfer
%       .img_id           Numeric stimulus ids presented on each transfer trial.
%                         Size: [nTransferTrials x 3]. Empty entries remain NaN.
%       .choice_idx       Chosen position on screen for transfer trials (1-based; computed as
%                         choice_screen_idx + 1).
% -------------------------------------------------------------------------
% Written by Romane Cecchi, 2025

function data_subj = format_sub_data_for_fitting(opt, db, sub, eye_data_stim, eye_data_out)

contexts = condi_spec(db.header(sub,:)); % Load contexts spec.

% Learning ---------------------------------------------------------- %
specL = db.expe.id == db.header.id(sub) & ismember(db.expe.phase, 'learning'); % Select participant learning trials
learning_data = db.expe(specL,:);

if ismember(opt.task, {'e1_forced'})
    is_not_forced = cellfun(@sum, learning_data.stim_is_clickable) - cellfun(@numel, learning_data.stim_id);
    is_not_forced(is_not_forced == 0) = 1; % Not forced = 1 | Forced = -1
elseif ismember(opt.task, {'e2_lum_stim', 'e3_lum_out'})
    is_not_forced = ones(height(learning_data),1);
end

data_subj.learning.cond_idx = (learning_data.condi_id + 1) .* is_not_forced; % Condition index (1 to 4 ; negative = forced choice)
data_subj.learning.outcome  = learning_data.choice_outcome; % Outcome de l'option choisie

unchosen_outcomes = cell2mat(cellfun(@(x) x', learning_data.stim_outcomes, 'UniformOutput', false)); % Get all outcomes
unchosen_outcomes(unchosen_outcomes == data_subj.learning.outcome) = NaN; % Remove chosen outcome

data_subj.learning.unchosen_out_max = max(unchosen_outcomes, [], 2); % Valeur de la meilleure option non choisie
data_subj.learning.unchosen_out_min = min(unchosen_outcomes, [], 2); % Valeur de la moins bonne option non choisie

sort_out = cell2mat(cellfun(@(x) x', cellfun(@sort, learning_data.stim_outcomes, 'UniformOutput', false), 'UniformOutput', false)); % Sorted outcomes
[~, data_subj.learning.choice_rank] = max(sort_out == learning_data.choice_outcome, [], 2); % Choice rank: 1 = worst, 2 = middle, 3 = best choice

data_subj.learning.img_id = NaN(height(contexts), max([contexts.nbChoiceOpt])); % Initialization
for c = 1:height(contexts) % Loop through contexts
    % Create a matrix similar to the Q-value matrix (condi * options (from worst to best)) with the corresponding image names
    data_subj.learning.img_id(c,:) = cell2mat(cellfun(@str2double, regexp(contexts(c).imgName, '\d*', 'match'), 'UniformOutput', false));
end % End of the loop through contexts

% Transfer ---------------------------------------------------------- %
specTT = db.expe.id == db.header.id(sub) & ismember(db.expe.phase, 'transfer'); % Select participant transfer trials
transfer_data = db.expe(specTT,:);

data_subj.transfer.img_id = NaN(height(transfer_data), 3); % Initialization
for trial = 1:height(transfer_data)
    % Id of symbols presented during the trial
    data_subj.transfer.img_id(trial, ~ismember(transfer_data.stim_id{trial}, '')) = cell2mat(cellfun(@str2double, regexp(transfer_data.stim_id{trial}, '\d*', 'match'), 'UniformOutput', false));
end

data_subj.transfer.choice_idx  = transfer_data.choice_screen_idx + 1; % Position of choice on screen

% Eye tracking  ----------------------------------------------------- %
specET = eye_data_out.id == db.header.id(sub);
eye_data_sub = eye_data_out(specET,:);
data_subj.learning.out_fix_ratio = eye_data_sub.fix_time_ratio; % Outcomes fixation time ratio (from worst to best option)
data_subj.learning.out_fix_course = eye_data_sub.fix_time_course; % Outcomes fixation time course (from worst to best option) | 0 = not looked; 1 = looked | 1000 pts = 1 sec

eye_data_sub = eye_data_stim(specET,:);
data_subj.learning.stim_fix_ratio = eye_data_sub.fix_time_ratio; % Stimuli fixation time ratio (from worst to best option)
data_subj.learning.stim_fix_course = eye_data_sub.fix_time_course; % Stimuli fixation time course (from worst to best option) | 0 = not looked; 1 = looked | 1000 pts = 1 sec

end