% Violin plot
%
% Creates a violin plot with mean, error bars, confidence interval and kernel density.
% Inspired by the functions of Sophie Bavard and Fabien Cerrotti and this link:
% https://neuraljojo.medium.com/use-matlab-to-create-beautiful-custom-violin-plots-c972358fa97a
%
% "opt" is a structure (optional) with these possible fields/options:
%   - opt.color = color of the violin
%   - opt.alpha = alpha for confidence interval
%   - opt.violinSpace = 'right', 'full' (default 'left')
%   - opt.showMean = true
%   - opt.showMedian = false
%   - opt.showCI = true
%   - opt.showSEM = true
%   - opt.width = width of the violin shape
%   - opt.pos = X position of the violin
%   - opt.showData = true
%   - opt.dataType = 'scatter' (default = 'scatter')
%   - opt.connectDots = true
% ----------------------------------------------------------------------- %
% Romane Cecchi, 2023

function violaPlot(data, opt)

% Set default option values

if ~exist('opt', 'var')
    opt = struct;
end

if ~isfield(opt, 'showMean')
    opt.showMean = true;
end

if ~isfield(opt, 'showCI')
    opt.showCI = true;
end

if ~isfield(opt, 'showSEM')
    opt.showSEM = true;
end

if ~isfield(opt, 'showData')
    opt.showData = true;
end

if ~isfield(opt, 'dataType')
    opt.dataType = 'scatter';
end

% ----------------------------------------------------------------------- %

if isfield(opt, 'alpha')
    arg.alpha = opt.alpha;
else
    arg.alpha = 0.05; % Default alpha
end

if isfield(opt, 'width')
    arg.width = opt.width;
else
    arg.width = 0.3; % Default width
end

if size(data,2) ~= 1 && size(data,1) == 1
    data = data'; % Columns = plots
end

for col = 1:size(data,2)

    if isfield(opt, 'pos')
        arg.pos = opt.pos;
    else
        arg.pos = col; % Default X position
    end

    if isfield(opt, 'color')
        arg.color = opt.color(col,:);
    else
        arg.color = [0 0.5 0.5]; % Default color
    end

    col_data = data(:,col);

    if sum(col_data) ~= 0

        %% Step 1: Create a kernel density function from data

        smooth = 1000; % Number of points to create the shape (the more points, the smoother the shape)
        yvalues = linspace(prctile(col_data,0.1), prctile(col_data,99.1), smooth); % Cut the "tail" off the violin (i.e., remove the outliers from the shape)
        bandwidth = std(col_data)/(numel(col_data)^(1/4)); % Modifies the bandwidth for the violin shape {MATLAB default: std(data)*(4/(3*size(data,1)))^(1/5)}
        [fdensity, xi] = ksdensity(col_data(:), yvalues, 'Bandwidth', bandwidth, 'BoundaryCorrection', 'reflection');

        if ~isnan(fdensity)

            % Change the width of the violin shape
            fromWidth = [0, max(fdensity)];
            toWidth = [0 arg.width];
            fdensity = interp1(fromWidth, toWidth, fdensity);

            xPoints = (0 - [fdensity, zeros(1, numel(xi), 1), 0]);
            xData = xPoints + arg.pos; % Default violinSpace: left
            yData = [xi, fliplr(xi), xi(1)];

            %% Step 2: Apply some options

            if isfield(opt, 'violinSpace')
                if ismember(opt.violinSpace, 'right')
                    xData = -xPoints + arg.pos;
                elseif ismember(opt.violinSpace, 'full')
                    xData = horzcat(xData, fliplr(-xPoints + arg.pos));
                    yData = horzcat(yData, fliplr(yData));
                else % Do nothing = default = left
                end
            end

            % If there are only 2 columns: ignore opt.violinSpace
            if isfield(opt, 'connectDots') && opt.connectDots && size(data,2) == 2 % If connectDots = 1 and there are only 2 columns
                if col == 1
                    xData = xPoints + arg.pos; % left
                    opt.violinSpace = 'left';
                elseif col == 2
                    xData = -xPoints + arg.pos; % right
                    opt.violinSpace = 'right';
                end
            end

            if isfield(opt, 'showMean') && opt.showMean
                yMean = mean(col_data);
                xMean = getXshape(xi, fdensity, yMean, arg.pos, opt);
            end

            if isfield(opt, 'showMedian') && opt.showMedian
                yMedian = median(col_data);
                xMedian = getXshape(xi, fdensity, yMedian, arg.pos, opt);
            end

            twoTailedAlpha = arg.alpha/2;
            SEM = std(col_data)/sqrt(length(col_data)); % Standard Error

            if isfield(opt, 'showSEM') && opt.showSEM

                SEMplot = [mean(col_data)-SEM mean(col_data)+SEM];
                yPt = linspace(SEMplot(1), SEMplot(2));
                ySEM = [yPt fliplr(yPt)];
                xSEM = getXshape(xi, fdensity, yPt, arg.pos, opt);

            end

            if isfield(opt, 'showCI') && opt.showCI

                ts = tinv([twoTailedAlpha  1-twoTailedAlpha], length(col_data)-1); % T-Score
                CI = mean(col_data) + ts * SEM; % Confidence Intervals

                yPt = linspace(CI(1), CI(2));
                yCI = [yPt fliplr(yPt)];
                xCI = getXshape(xi, fdensity, yPt, arg.pos, opt);

            end

            %% Step 3: Plot the figure
            hold on;

            % Violin shape
            patch('XData', xData,...
                'YData', yData,...
                'FaceColor', arg.color,...
                'FaceAlpha', 0.2,...
                'EdgeColor', 'none')

            % Confidence interval
            if isfield(opt, 'showCI') && opt.showCI
                patch('XData', xCI,...
                    'YData', yCI,...
                    'FaceColor', arg.color,...
                    'FaceAlpha', 0.3,...
                    'EdgeColor', 'none')
            end

            % Standard error
            if isfield(opt, 'showSEM') && opt.showSEM
                patch('XData', xSEM,...
                    'YData', ySEM,...
                    'FaceColor', arg.color,...
                    'FaceAlpha', 0.4,...
                    'EdgeColor', 'none')
            end

            % Averages
            if isfield(opt, 'showMean') && opt.showMean
                plot(xMean, repmat(yMean,1,2), 'Color', 'k', 'LineWidth', 2)
            end

            if isfield(opt, 'showMedian') && opt.showMedian
                plot(xMedian, repmat(yMedian,1,2), 'Color', 'r', 'LineWidth', 2)
            end

        end % End of the condition if fdensity ~= NaN
    end % End of the condition if data ~= 0

    if isfield(opt, 'showData') && opt.showData

        switch opt.dataType
            case 'scatter'

                scattSign = 1; % Default : left
                if isfield(opt, 'violinSpace')
                    if ismember(opt.violinSpace, 'right')
                        scattSign = -1;
                    elseif ismember(opt.violinSpace, 'full')
                        scattSign = 0;
                    end
                end

                if isfield(opt, 'connectDots') && opt.connectDots

                    rng('shuffle');
                    jit = round(sort([arg.pos + (arg.width * scattSign), arg.pos + (0.02 * scattSign)]) * 500);
                    jitX(:,col) = randi(jit, [1 numel(col_data)]) / 500; % Get the exact X position of each point

                    tic
                    timeSpent = 0;
                    while timeSpent < 0.5 && length(unique(round([jitX(:,col) col_data],2), 'rows')) ~= length(col_data)
                        jitX(:,col) = randi(jit, [1 numel(col_data)]) / 500;
                        timeSpent = timeSpent + toc;
                    end

                    s = scatter(jitX(:,col), col_data);

                else

                    % Scatter (individual points)
                    s = swarmchart(ones(1, numel(col_data)) * arg.pos + (arg.width/2 * scattSign), col_data, 'filled');
                    s.XJitterWidth = arg.width / 1.2;

                end

                s.MarkerFaceColor = arg.color;
                s.MarkerEdgeColor = 'none';
                s.MarkerFaceAlpha = 0.3;
                s.SizeData = 20;

        end % End of dataType

    end % End of showData

end % End of loop through data columns

if isfield(opt, 'connectDots') && opt.connectDots

    for bin = 1:size(data,2) - 1

        lineX = jitX(:,bin:bin+1)';
        lineY = data(:,bin:bin+1)';
        plot(lineX, lineY, '-', 'Color', [.7 .7 .7])

    end

end

end