function S = stadium_reuse_study(outdir, seeds)
%STADIUM_REUSE_STUDY  "The crowd is the shield": reuse-3 vs FFR vs reuse-1.
%   (a) capacity vs number of under-seat cells, packed crowd
%   (b) capacity at 24 cells vs crowd body loss -> crossover FFR -> reuse-1
if nargin < 1, outdir = '.'; end
if nargin < 2, seeds = 1:5; end
schemes = {'reuse3', 'ffr', 'reuse1'};
names   = {'Reuse-3 (classic)', 'Fractional freq. reuse', 'Reuse-1 (same 100 MHz everywhere)'};
cols    = {[.6 .6 .6], [.13 .13 .13], [.89 0 0]};
S.N = [12 18 24 30 36 48 60 72];
S.alpha = [0 0.05 0.1 0.15 0.2 0.3 0.4 0.5];
for k = 1:3
    for i = 1:numel(S.N)
        t = reuse_sim_run(S.N(i), schemes{k}, 0.3, 7);  S.capN(k, i) = t.total_gbps;
    end
    for i = 1:numel(S.alpha)
        v = zeros(size(seeds));
        for j = 1:numel(seeds), t = reuse_sim_run(24, schemes{k}, S.alpha(i), seeds(j));  v(j) = t.total_gbps; end
        S.capA(k, i) = mean(v);  S.capA_sd(k, i) = std(v);
    end
end
fprintf('\n== Seat-zone reuse (24 cells) ==\n');
fprintf('%-28s', 'crowd loss dB/m'); fprintf('%7.2f', S.alpha); fprintf('\n');
for k = 1:3, fprintf('%-28s', names{k}); fprintf('%7.2f', S.capA(k, :)); fprintf('  Gbps\n'); end

fig = figure('Name', 'Seat-zone reuse', 'Position', [100 100 1000 380]);
subplot(1, 2, 1);
for k = 1:3, plot(S.N, S.capN(k, :), '-o', 'Color', cols{k}, 'LineWidth', 1.8); hold on; end
xlabel('Under-seat small cells'); ylabel('Layer capacity (Gbps)'); grid on;
title('Packed crowd (0.3 dB/m)'); legend(names, 'Location', 'northwest');
subplot(1, 2, 2);
for k = 1:3, plot(S.alpha, S.capA(k, :), '-o', 'Color', cols{k}, 'LineWidth', 1.8); hold on; end
xlabel('Crowd body loss (dB per metre)'); ylabel('Capacity, 24 cells (Gbps)'); grid on;
title('Best scheme flips as the stadium fills');
print(fig, fullfile(outdir, 'fig_crossover.png'), '-dpng', '-r200');
end
