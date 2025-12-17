function [out] = get_fix_time_nary(init)

%% Loop through participants

w = waitbar(0, 'Starting...');

for part = 1:height(init.db.header)

    clearvars -except init part out w
    id = init.db.header.part_id{part};

    waitbar(part/height(init.db.header), w, sprintf('Processing of participant %d / %d', part, height(init.db.header)));

    % Header data
    select    = ismember(init.db.header.part_id, id);
    part_info = init.db.header(select,:); % Header data

    % Trials data (1 row = 1 trial)
    select     = ismember(init.db.expe.part_id, id) & ismember(init.db.expe.phase, init.phase); % Select participant transfer trials
    phase_data = init.db.expe(select,:);

    % Eye data
    load(fullfile(init.path, 'Eye_data', init.task, sprintf('%s_%s.mat', id, init.task)), 'part_eye'); % Load 'part_eye'

    start_phase = part_eye.events.timestamp(contains(part_eye.events.value, sprintf('Start of %s', init.phase)));
    end_phase = part_eye.events.timestamp(contains(part_eye.events.value, sprintf('End of %s', init.phase)));
    phase_eye.data = part_eye.data(part_eye.data.timestamp >= start_phase & part_eye.data.timestamp <= end_phase,:);
    phase_eye.events = part_eye.events(part_eye.events.timestamp >= start_phase & part_eye.events.timestamp <= end_phase,:);

    contexts = condi_spec(part_info);
    condi_count = struct;

    for trial = 1:height(phase_data)

        switch init.phase_part
            case 'stimuli'
                part_display = find(ismember(phase_eye.events.value, sprintf('Timing: Start of trial: %d ', trial-1)));
                part_cleared = find(ismember(phase_eye.events.value, sprintf('Timing: Decision Time : trial %d ', trial-1)));
            case 'outcomes'
                part_display = find(ismember(phase_eye.events.value, sprintf('Timing: Outcomes display : trial %d ', trial-1)));
                if trial ~= height(phase_data)
                    part_cleared = find(ismember(phase_eye.events.value, sprintf('Timing: Start of trial: %d ', trial)));
                elseif trial == height(phase_data) % Last trial
                    part_cleared = height(phase_eye.events);
                end
        end

        if numel(part_display) ~= 1 || numel(part_cleared) ~= 1
            error('multiple events found')
        elseif part_cleared < part_display
            error('trial detection problem')
        end

        % Find all the data points in the trial
        data_ts = phase_eye.data.timestamp;
        event_ts_start = phase_eye.events.timestamp(part_display);
        event_ts_end   = phase_eye.events.timestamp(part_cleared);

        idx = data_ts >= event_ts_start & data_ts < event_ts_end;
        trial_data = phase_eye.data(idx, :);
        trial_events = phase_eye.events(part_display:part_cleared,:);

        for aoi = 1:numel(init.aoi_names) % Loop through AOIs (left, middle, right)

            switch init.opt_splitting

                case 'value'

                    % Get AOI condition
                    if ismember(init.task, {'e1_forced'}) % Forced task
                        nary = sum(phase_data(trial,:).stim_is_clickable{:});
                    elseif ismember(init.task, {'e2_lum_stim', 'e3_lum_out'}) % Luminance task
                        nary = find(sort(phase_data.stim_mean_values{trial}) == ...
                            nonzeros(phase_data.stim_mean_values{trial} .* phase_data.out_is_higher_lumi{trial}));
                    end

                    aoi_condi = sprintf('%s%d_%d', contexts(phase_data(trial,:).condi_id+1,:).condi_name, ...
                        phase_data(trial,:).stim_mean_values{:}(aoi), nary);

                case 'mergeWNvalue'

                    % Get AOI condition
                    if ismember(init.task, {'e1_forced'}) % Forced task

                        stim_clickable = phase_data.stim_is_clickable{trial};
                        nary = sum(stim_clickable);

                    elseif ismember(init.task, {'e2_lum_stim', 'e3_lum_out'}) % Luminance task

                        stim_values = phase_data.stim_mean_values{trial};
                        out_is_higher = phase_data.out_is_higher_lumi{trial};

                        nary = find(sort(stim_values) == nonzeros(stim_values .* out_is_higher));
                    end

                    if phase_data.stim_mean_values{trial}(aoi) == min(phase_data.stim_mean_values{trial})
                        pos = 'min';
                    elseif phase_data.stim_mean_values{trial}(aoi) == max(phase_data.stim_mean_values{trial})
                        pos = 'max';
                    else
                        pos = 'mid';
                    end

                    aoi_condi = sprintf('%s_%s_%d', contexts(phase_data.condi_id(trial)+1,:).condi_name(2:end), pos, nary);

            end

            % ----------------------------------------------------------- %

            aoi_coord = init.aoi.(init.aoi_names{aoi});

            if ~isfield(condi_count, aoi_condi)
                condi_count.(aoi_condi) = 1;
            else
                condi_count.(aoi_condi) = condi_count.(aoi_condi) + 1;
            end

            if ismember(init.var_of_int, {'fixation'})

                count = sum(trial_data.xPos_norm >= aoi_coord.x(1) & trial_data.xPos_norm <= aoi_coord.x(2) ...
                    & trial_data.yPos_norm >= aoi_coord.y(1) & trial_data.yPos_norm <= aoi_coord.y(end));

                trial_time = height(trial_data); % In ms

                % Remove blink from total time
                blink = find(ismember(trial_events.type, 'BLINK'));
                for bk = 1:numel(blink)
                    if (trial_data.timestamp(end) - trial_events(blink(bk),:).timestamp) > trial_events(blink(bk),:).duration
                        blink_dur = trial_events(blink(bk),:).duration;
                    else % Blink duration exceeds the end of the trial
                        blink_dur = trial_data.timestamp(end) - trial_events(blink(bk),:).timestamp; % Time remaining until end of trial
                    end
                    trial_time = trial_time - blink_dur;
                end

                fix_time_ratio_part.(aoi_condi)(condi_count.(aoi_condi)) = count / trial_time;

            end

        end % End of the loop through AOIs
    end % End of the loop through trials

    if part == 1
        out.all_options = natsort(fieldnames(fix_time_ratio_part), [], 'descend');
    end

    for cond = 1:numel(out.all_options)
        out.nb_fix_ratio.(out.all_options{cond})(part) = mean(fix_time_ratio_part.(out.all_options{cond}), 'omitnan');

        if ~isfield(out, 'fix_trial_ratio') || ~isfield(out.fix_trial_ratio, out.all_options{cond})
            sizeD = numel(fix_time_ratio_part.(out.all_options{cond}));
        else
            sizeD = max([size(out.fix_trial_ratio.(out.all_options{cond}),2) numel(fix_time_ratio_part.(out.all_options{cond}))]);
            out.fix_trial_ratio.(out.all_options{cond}) = paddata(out.fix_trial_ratio.(out.all_options{cond}), sizeD, Dimension = 2, FillValue = NaN);
        end

        out.fix_trial_ratio.(out.all_options{cond})(part,:) = paddata(fix_time_ratio_part.(out.all_options{cond}), sizeD, Dimension = 2, FillValue = NaN);
    end

end % End of the loop through participants

delete(w);

if init.plot == 1

    switch init.opt_splitting
        case {'value'}
            condi = {contexts.condi_name};
        case 'mergeWNvalue'
            condi = {'100', '50'};
    end

    opt_nb.ternary = out.all_options(contains(out.all_options, '_3'));
    opt_nb.binary = out.all_options(contains(out.all_options, '_2'));
    opt_nb_names = fieldnames(opt_nb);

    %% Figure 1: Mean choice rate

    fig = figure;
    t = tiledlayout(2, numel(condi), 'TileSpacing', 'Compact');

    for nary = 1:numel(opt_nb_names) % Loop over binary/ternary conditions
        for c = 1:numel(condi) % Loop through conditions

            nexttile
            hold on;

            count = 0;
            opt = opt_nb.(opt_nb_names{nary})(contains(opt_nb.(opt_nb_names{nary}), condi{c}));

            for val = 1:numel(opt) % Loop on condition options

                count = count + 1;

                data = out.nb_fix_ratio.(opt{val});

                if ismember(init.var_of_int, {'pupil'})
                    data(isnan(data)) = [];
                end

                o.violinSpace = 'right';
                o.pos = count;
                o.showData = true;

                switch init.opt_splitting
                    case {'value'}
                        o.color = contexts(ismember({contexts.condi_name}, condi{c})).color;
                    case 'mergeWNvalue'
                        o.color = contexts(find(contains({contexts.condi_name}, condi{c}),1)).color;
                end

                violaPlot(data, o)

            end

            switch init.opt_splitting
                case {'mergeWNvalue'}
                    opt_digit = cellfun(@(x) regexp(x, '(?<=_)\w*(?=_)', 'match'), opt, 'UniformOutput', false);
                case 'value'
                    opt_digit = cellfun(@(x) regexp(x, '\d*', 'match'), opt, 'UniformOutput', false);
            end

            xLabels = cellfun(@(x) x{1}, opt_digit, 'UniformOutput', false);

            % Axes
            if nary == 1
                title(condi{c})
            end

            if ismember(init.task, {'e1_forced'}) && c == 1
                ylabel(opt_nb_names{nary})
            elseif ismember(init.task, {'e2_lum_stim', 'e3_lum_out'}) && c == 1

                if ismember(init.task, {'e2_lum_stim'})
                    lum_target = 'stimulus';
                elseif ismember(init.task, {'e3_lum_out'})
                    lum_target = 'outcome';
                end

                if ismember(opt_nb_names{nary}, {'ternary'})
                    ylabel(sprintf('Lum on max %s', lum_target))
                elseif ismember(opt_nb_names{nary}, {'binary'})
                    ylabel(sprintf('Lum on mid %s', lum_target))
                end
            end

            xticks(1:count)
            xticklabels(xLabels)
            xlim([0 count+1]);

            ylim([0 1]);

            % Line
            yl = plot(xlim, [1/3 1/3], 'k--', 'LineWidth', .5);
            uistack(yl,'bottom')

        end % End of the loop through conditions
    end % End of the loop through binary/ternary conditions

    xlabel(t,'Option value')

    if ismember(init.var_of_int, {'fixation'})

        ylabel(t,'Fixation ratio')
        title(t, sprintf('%s fixation time rate during %s', regexprep(init.phase_part,'(\<[a-z])','${upper($1)}'), init.phase))

    end

    suff = '';
    switch init.opt_splitting
        case {'mergeWNvalue'}
            suff = '_merged_range';
    end

    % Save
    figSize = [20 20]; % [width height]
    fig.PaperPosition = [0, 0, figSize]; % [left bottom width height]
    fig.PaperSize = figSize;
    if ismember(init.var_of_int, {'fixation'})
        fig_name = fullfile(fileparts(init.path), 'Figures', 'Eye', sprintf('%s_fix_time_rate_bi_ternary_%s_%s%s', init.task, init.phase, init.phase_part, suff));
    end
    print(fig, fig_name, '-dpdf', '-r200', '-image');

    close(fig)

end % End of if init.plot == 1

if ismember(init.opt_splitting, {'mergeWNvalue'})

    %% Repeated measures ANOVA (3*3)

    ranova_data = structfun(@(x) x', out.nb_fix_ratio, 'UniformOutput', 0);
    ranova_tbl = struct2table(ranova_data);

    fields = fieldnames(out.nb_fix_ratio);
    wi.condi = cellfun(@(x) x(1:regexp(x, '_', 'once')-1), fields, 'UniformOutput', 0);
    wi.option = cellfun(@(x) x(end-4:end-2), fields, 'UniformOutput', 0);
    wi.trial_type = cellfun(@(x) x(end), fields, 'UniformOutput', 0);

    % Create an interaction factor capturing each combination of levels
    wi2 = wi;
    wi2.condi_option = cellfun(@(x) x([1:regexp(x, '_', 'once')-1, end-4:end-2]), fields, 'UniformOutput', 0);
    wi2.condi_trial_type = cellfun(@(x) [x(1:regexp(x, '_', 'once')-1), '_', x(end)], fields, 'UniformOutput', 0);
    wi2.option_trial_type = cellfun(@(x) x([end-4:end-2, end]), fields, 'UniformOutput', 0);

    within = struct2table(wi2);

    rm = fitrm(ranova_tbl, sprintf('%s ~ 1', char(join(fields, ','))), 'WithinDesign', within);
    ranova_results = ranova(rm, 'withinmodel', 'condi * option * trial_type');

    % Get partial eta squared
    % Formula : η2p = SS_effect / (SS_effect + SS_error_within)
    SS_effect = ranova_results.SumSq(contains(ranova_results.Properties.RowNames, {'(Intercept)'}));
    SS_error_within = ranova_results.SumSq(contains(ranova_results.Properties.RowNames, {'Error'}));
    ranova_results.partialeta2(contains(ranova_results.Properties.RowNames, {'(Intercept)'})) = SS_effect ./ (SS_effect + SS_error_within);

    fprintf(['---------------------------------------------------------\n' ...
        '\t\t\t %s \n' ...
        '---------------------------------------------------------'], upper(init.phase_part))

    fprintf('\n--------------- Repeated measures ANOVA ---------------\n\n')
    disp(ranova_results)

    % Test sphericity
    sphericity_warn(rm)

    % Post-hoc (ranova)
    if ranova_results{['(Intercept):' strjoin(fieldnames(wi), ':')], 'pValueGG'} < .05 % If the interaction is significant

        fprintf('\n--------------- Post-hoc: option by condi+trial type---------------\n\n')
        disp(multcompare(rm, 'option', 'by', 'condi_trial_type'))
        fprintf('\n--------------- Post-hoc: condi+trial type by option---------------\n\n')
        disp(multcompare(rm, 'condi_trial_type', 'by', 'option'))
        fprintf('\n--------------- Post-hoc: condi by option ---------------\n\n')
        disp(multcompare(rm, 'condi', 'by', 'option'))

    end

end

end