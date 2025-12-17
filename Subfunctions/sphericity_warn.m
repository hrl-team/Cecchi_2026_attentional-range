% Performs a sphericity test (which is an important assumption in
% repeated-measures ANOVA) and returns a warning with the name of the
% appropriate correction if sphericity is not respected
%
% INPUT:
% - rm = Repeated measures model (done with 'fitrm')
%
% OUTPUT: Based on Verma (2015) p.84

function sphericity_warn(rm)

m_test = mauchly(rm);

if m_test.pValue < .05
    eps = epsilon(rm);
    if eps.GreenhouseGeisser < .75
        adjustment_name = 'Greenhouse-Geisser';
    else
        adjustment_name = 'Huynh-Feldt';
    end
    warning('Sphericity does not hold, use %s adjustment (corrected p-value)', adjustment_name)
else
    fprintf('\nSphericity is maintained, no adjustment required\n\n')
end

end