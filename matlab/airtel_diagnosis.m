function R = airtel_diagnosis(D, outdir)
%AIRTEL_DIAGNOSIS  What actually failed at the last match (65,000 fans).
%   1) 5G attach success vs 4G anchor load  -> hard admission cap on B3
%   2) 4G user speed vs load                -> M/G/1 processor sharing fit
%   3) UPI failure vs load                  -> exponential fit
if nargin < 2, outdir = '.'; end
sat = D.ld_lm > 95;
R.n_sat     = nnz(sat);
R.succ_min  = min(D.succ(sat));  R.succ_max = max(D.succ(sat));
R.succ_mean = mean(D.succ(sat)); R.succ_std = std(D.succ(sat), 1);
R.DoverC    = 100 / R.succ_mean;            % success = C / D under a hard cap

% M/G/1-PS: r = Rpk (1 - rho), least squares through the origin in (1 - rho)
rho = [D.ld_nd; D.ld_lm] / 100;  r = [D.s4_nd; D.s4_lm];
R.R4 = sum(r .* (1 - rho)) / sum((1 - rho).^2);
R.ps_r2 = 1 - sum((r - R.R4 * (1 - rho)).^2) / sum((r - mean(r)).^2);
ok = ~isnan(D.s5_nd);
R.R5 = median(D.s5_nd(ok) ./ (1 - D.ld_nd(ok) / 100));

% UPI: failure = a + b * exp(k * load), fitted on phase-average loads (M6 excluded)
phases = unique_stable(D.phase);
noM6 = ~strcmp(D.site, 'M6');
for i = 1:numel(phases)
    m = strcmp(D.phase, phases{i});
    R.ld_lm_avg(i) = mean(D.ld_lm(m & noM6));
    R.ld_nd_avg(i) = mean(D.ld_nd(m));
    R.succ_avg(i)  = mean(D.succ(m & noM6));
    R.s4_avg(i)    = mean(D.s4_lm(m & noM6));
end
R.phases = phases;
x = [R.ld_nd_avg(:); R.ld_lm_avg(:)];  y = [D.upi_nd(:); D.upi_lm(:)];
f = @(p, x) p(1) + exp(p(2)) * exp(p(3) * (x - 100));
loss = @(p) sum((f(p, x) - y).^2);
R.upi_p = fminsearch(loss, [1.1, log(6), 0.1], optimset('MaxFunEvals', 2e4, 'MaxIter', 2e4));
R.upi_fun = @(L) f(R.upi_p, L);

fprintf('\n== Diagnosis on Airtel data ==\n');
fprintf('Saturated cell-moments          : %d\n', R.n_sat);
fprintf('5G success when saturated       : %.1f-%.1f %% (std %.2f)\n', R.succ_min, R.succ_max, R.succ_std);
fprintf('Attach demand / anchor capacity : %.2f\n', R.DoverC);
fprintf('Processor sharing 4G            : r = %.1f (1-rho) Mbps, R^2 = %.3f\n', R.R4, R.ps_r2);
fprintf('5G peak (normal day)            : %.0f Mbps\n', R.R5);

fig = figure('Name', 'Airtel diagnosis', 'Position', [100 100 1000 380]);
subplot(1, 2, 1);
plot(D.ld_nd, 99.2 * ones(size(D.ld_nd)), 'o', 'Color', [.6 .6 .6], 'MarkerFaceColor', [.6 .6 .6]); hold on;
plot(D.ld_lm, D.succ, 'o', 'Color', [.89 0 0], 'MarkerFaceColor', [.89 0 0]);
xlabel('4G anchor (B3) load %'); ylabel('5G connection success %'); ylim([0 105]); grid on;
title(sprintf('Attach collapses: %d saturated points at %.0f-%.0f%%', R.n_sat, R.succ_min, R.succ_max));
legend('Normal day', 'Last match', 'Location', 'southwest');
subplot(1, 2, 2);
plot(rho * 100, r, 'o', 'Color', [.89 0 0], 'MarkerFaceColor', [.89 0 0]); hold on;
xx = linspace(0, 1, 100); plot(xx * 100, R.R4 * (1 - xx), 'k-', 'LineWidth', 1.6);
xlabel('Anchor load % (\rho)'); ylabel('4G user speed (Mbps)'); grid on;
title(sprintf('M/G/1-PS: r = %.1f(1-\\rho), R^2 = %.2f', R.R4, R.ps_r2));
print(fig, fullfile(outdir, 'fig_airtel_diagnosis.png'), '-dpng', '-r200');
end

function u = unique_stable(s)
u = {};
for i = 1:numel(s)
    if ~any(strcmp(u, s{i})), u{end + 1, 1} = s{i}; end %#ok<AGROW>
end
end
