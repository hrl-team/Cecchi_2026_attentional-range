function contexts = condi_spec(db_header_part)

contexts = db_header_part.exp_param{:}.condiObj.learning;

for cont = 1:numel(contexts) % Loop through contexts

    if isfield(contexts(cont), 'nbOptWhenForced')

        switch contexts(cont).nbOptWhenForced
            case 3
                forced_condi = 't100'; % 100% ternary
            case 2
                forced_condi = 'b50'; % 50% binary
        end

    elseif isfield(contexts(cont), 'imgPercentHighLumi')

        switch contexts(cont).imgPercentHighLumi(2)
            case 0
                forced_condi = 'h100'; % 100% High-value
            case 50
                forced_condi = 'm50'; % 50% Mid-value
        end

    end

    contexts(cont).condi_name = sprintf('%s%s', upper(contexts(cont).amplitude(1)), forced_condi);

    switch contexts(cont).condi_name
        case {'Wt100', 'Wh100'}
            contexts(cont).color = [74, 101, 193] / 255;
        case {'Wb50', 'Wm50'}
            contexts(cont).color = [238, 125, 80] / 255;
        case {'Nt100', 'Nh100'}
            contexts(cont).color = [140, 113, 175] / 255;
        case {'Nb50', 'Nm50'}
            contexts(cont).color = [246, 167, 68] / 255;
    end
end

end