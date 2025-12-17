%
% Sample a single 1x4 probability vector p ~ Dirichlet(alpha).
%
% INPUT
%   alpha : 1x4 positive parameters (e.g., from dirichlet_mle)
%
% OUTPUT
%   p : 1x4 vector, sums to 1

function p = sample_dirichlet(alpha)

% --- Gamma trick: draw independent Gammas and normalize
y = gamrnd(alpha, 1); % shape = alpha_i, scale = 1 for each component
p = y ./ sum(y);
end