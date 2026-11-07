function P = current_vs_ours(R, plan, outdir)
%CURRENT_VS_OURS  Same calibrated models, last match (measured) vs final (predicted).
%   plan.anchor_ratio : anchor capacity, ours / current (multi-anchor + new cells)
%   plan.rho4, plan.rho5 : planned peak load on 4G / 5G after the fix
if nargin < 3, outdir = '.'; end
growth = 100000 / 65000;
n = numel(R.phases);
for i = 1:n
    saturated = R.ld_lm_avg(i) > 95;
    if saturated, d = R.DoverC; s = plan.rho4; s5 = plan.rho5; else, d = R.ld_lm_avg(i) / 100; s = plan.rho4 * d / R.DoverC; s5 = plan.rho5 * d / R.DoverC; end
    dF = d * growth;
    P.succ_now(i)   = R.succ_avg(i);
    P.succ_dn(i)    = 100 * min(1, 1 / dF);                    % do nothing at the final
    P.succ_ours(i)  = min(99.2, 99.2 * plan.anchor_ratio / dF);
    P.s4_now(i)     = R.s4_avg(i);
    P.s4_ours(i)    = R.R4 * (1 - s);
    P.s5_ours(i)    = R.R5 * (1 - s5);
    P.upi_ours(i)   = R.upi_fun(R.ld_nd_avg(i));              % payments isolated from load by QoS
end
P.upi_now = plan.upi_now(:)';

fprintf('\n== Final (1,00,000 fans): current vs ours ==\n');
fprintf('%-20s %10s %10s %10s %10s %10s %10s\n', 'Phase', '5G now', '5G DN', '5G ours', '4G now', '4G ours', 'UPI ours');
for i = 1:n
    fprintf('%-20s %9.1f%% %9.1f%% %9.1f%% %8.2f M %8.2f M %9.2f%%\n', R.phases{i}, P.succ_now(i), P.succ_dn(i), ...
        P.succ_ours(i), P.s4_now(i), P.s4_ours(i), P.upi_ours(i));
end

fig = figure('Name', 'Current vs ours', 'Position', [100 100 1100 360]);
lab = {'Build-up', 'Innings', 'Final over', 'Post-match'};
grey = [.6 .6 .6]; red = [.89 0 0];
subplot(1, 3, 1); b = bar([P.succ_now; P.succ_ours]'); title('5G connection success %');
subplot(1, 3, 2); b2 = bar([P.s4_now; P.s4_ours]'); title('4G user speed (Mbps)'); hold on; plot([0.5 4.5], [3 3], 'k:');
subplot(1, 3, 3); b3 = bar([P.upi_now; P.upi_ours]'); title('UPI failure %');
for bb = {b, b2, b3}
    set(bb{1}(1), 'FaceColor', grey); set(bb{1}(2), 'FaceColor', red);
end
for k = 1:3, subplot(1, 3, k); set(gca, 'XTickLabel', lab); grid on; end
subplot(1, 3, 1); legend('Current (last match)', 'Ours (final)', 'Location', 'southwest');
print(fig, fullfile(outdir, 'fig_current_vs_ours.png'), '-dpng', '-r200');
end
