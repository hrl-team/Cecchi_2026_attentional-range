%
% Convert per-component mean and std of 4-part fixation shares
% (min, mid, max, else) into a 1x4 Dirichlet parameter vector alpha.
%
% INPUTS
%   mu : 1x4 vector of means in [0,1], order: [min, mid, max, else]
%   sd : 1x4 vector of standard deviations (over trials), same order
%
% IMPORTANT
% - mu and sd must be computed across trials from *normalized shares*:
%   for each trial t, shares sum to 1: p_t = [min, mid, max, else].
%
% OUTPUT
%   alpha : 1x4 Dirichlet parameters (positive). Use with sample_dirichlet().

function alpha = dirichlet_mle(mu, sd)

% --- Safety: clip means into (eps, 1-eps) to avoid divide-by-zero.
eps0 = 1e-8;
mu = max(min(mu(:)', 1 - eps0), eps0);   % row vector, strictly inside (0,1)

% --- Variances from std
v = sd(:)'.^2;

% --- Per-dimension alpha0 candidates (method-of-moments)
%     alpha0_i = mu_i*(1-mu_i)/var_i - 1
a0_i = (mu .* (1 - mu)) ./ max(v, 1e-12) - 1;

% --- Keep only sensible candidates (positive, finite)
ok = isfinite(a0_i) & (a0_i > 0);
if any(ok)
    a0 = median(a0_i(ok));      % robust center across components
    a0 = max(a0, 1e-3);         % clip to small positive if tiny
else
    % Fallback when variances ~0 or data are degenerate:
    a0 = 200;                   % "very tight around mean" default
end

% --- Final Dirichlet vector
alpha = mu * a0;

% --- Final safety clip (strictly positive)
alpha = max(alpha, 1e-6);
end