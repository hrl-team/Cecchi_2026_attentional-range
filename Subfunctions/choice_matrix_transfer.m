function choice_matrix_transfer(db, savepath, opt)

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
    row = db.expe.id == db.header.id(part) & ismember(db.expe.phase, 'transfer'); % Select participant transfer trials
    transfer_data = db.expe(row,:);

    contexts = condi_spec(db.header(part,:));

    % Create a table with stim infos
    varNames = ["Name", "Context"];
    varTypes = ["string", "string"];
    stim_info = table('Size',[0 2],'VariableTypes',varTypes,'VariableNames',varNames);

    imgCount = 0;
    for cont = 1:numel(contexts) % Loop through contexts
        for img = 1:numel(contexts(cont).imgName) % Loop through options of the context
            imgCount = imgCount + 1;
            stim_info(imgCount,:) = {contexts(cont).imgName{img},...
                sprintf('c%s%s%i', contexts(cont).condi_name(3:end), contexts(cont).condi_name(1), contexts(cont).imgMean(img))};
        end % End of the loop through options of the context
    end % End of the loop through contexts

    stim_info = sortrows(stim_info,'Context'); % Re-order conditions (for the figure)

    for stim = 1:height(stim_info) % Loop through options

        imgName = stim_info.Name(stim);
        counter = zeros(height(stim_info),1); % Nb of times the two options were presented together
        chosen = zeros(height(stim_info),1); % Nb of times the option was chosen

        % Find trials where this option was presented (+ its position on the screen)
        img_idx = cellfun(@(x) find(strcmp(x, imgName)), transfer_data.stim_id, 'UniformOutput', false);
        img_idx(cellfun(@isempty, img_idx)) = {0};
        img_idx = cell2mat(img_idx);

        for trial = 1:height(transfer_data) % Loop through trials
            if img_idx(trial) ~= 0 % If the option was presented in this trial

                trial_data = transfer_data(trial,:);
                trial_choice_idx = trial_data.choice_screen_idx + 1; % Index of the chosen option
                stimPos = img_idx(trial); % Current option index

                second_opt_name = trial_data.stim_id{:}{~ismember(trial_data.stim_id{:}, imgName) & ~cellfun(@isempty, trial_data.stim_id{:})}; % Name of the other presented option
                second_opt_idx = ismember(stim_info.Name, second_opt_name);
                counter(second_opt_idx) = counter(second_opt_idx) + 1;

                if stimPos == trial_choice_idx % If the image was chosen
                    chosen(second_opt_idx) = chosen(second_opt_idx) + 1;
                end

            end % End of condition if option was in trial
        end % End of the loop through trials

        out.choice_rate(opt.part_count).(stim_info.Context(stim)) = array2table((chosen ./ counter).', 'VariableNames', stim_info.Context);

    end % End of the loop through options
end % End of the loop through participants

clearvars -except db savepath opt out

%% Figure

condi = fieldnames(out.choice_rate);

for cond = 1:numel(condi) % Loop through conditions
    choice_matrix(:,cond) = table2array(mean(vertcat(out.choice_rate.(condi{cond}))));
end

fig = figure;
hm = heatmap(condi, condi, choice_matrix);

lim = [0 1];
clim(lim) % Limits of the colorbar

hm.GridVisible = 'off';

cb = hm.NodeChildren(2); % Access colorbar
cb.Label.String = "Option 1 choice rate";
cb.Label.Rotation = 270;
cb.Label.VerticalAlignment = "bottom";
cb.Label.FontSize = 12;

xlabel('Option 1')
ylabel('Option 2')

% Define colors
clearvars C

C.n1 = [1 156 205]/255;
C.n2 = [255 255 255]/255; % White
C.n3 = [213 110 169]/255;

cnum = fieldnames(C);
map_length = 256;
newmap = NaN(map_length,3);

for i = 1:3 % RGB
    start_pt = 1;
    for j = 1:(numel(cnum)-1) % Loop through segments
        end_pt = start_pt + map_length/(numel(cnum)-1) - 1;
        newmap(start_pt:end_pt,i) = linspace(C.(cnum{j})(i), C.(cnum{j+1})(i), map_length/(numel(cnum)-1));
        start_pt = end_pt + 1;
    end
end

colormap(newmap)

% Save
figSize = [25 25]; % [width height]
fig.PaperPosition = [0, 0, figSize]; % [left bottom width height]
fig.PaperSize = figSize;
fig_name = fullfile(savepath, 'Figures', 'Behavior', sprintf('%s_choice_matrix_transfer.pdf', opt.task));
exportgraphics(fig, fig_name, 'ContentType', 'image', 'Resolution', 300)

close(fig)

end % End of the main function