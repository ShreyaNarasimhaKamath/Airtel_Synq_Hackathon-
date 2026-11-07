%% Stadium Surge - Airtel Sync 2026 (Network Track)
% Amritha S, Shreya Kamath - VIT Chennai
%
% Part A: diagnosis on Airtel's own dataset (Sync_V1.xlsx)
% Part B: M-QAM over flat Rayleigh fading - Monte Carlo vs theory
% Part C: link-to-system mapping (3GPP TR 36.942 Annex A.2)
%
% Needs: MATLAB + Communications Toolbox. Put Sync_V1.xlsx next to this file.

clear; clc; close all;

%% ---------------- Part A: Airtel dataset ----------------
T = readcell('Sync_V1.xlsx', 'Range', 'A3:J34');
site  = string(T(:,1));
ldND  = cell2mat(T(:,4));  ldLM = cell2mat(T(:,5));
s4ND  = cell2mat(T(:,6));  s4LM = cell2mat(T(:,7));
succ  = cell2mat(T(:,10));

sat = ldLM > 95;
fprintf('Saturated cell-moments: %d\n', nnz(sat));
fprintf('5G success when saturated: %.1f - %.1f %% (std %.2f)\n', ...
        min(succ(sat)), max(succ(sat)), std(succ(sat),1));
DoverC = 100 / mean(succ(sat));          % hard admission cap: success = C/D
fprintf('Attach demand / anchor capacity at last match = %.2f\n', DoverC);

% M/G/1 processor sharing: r = Rpeak * (1 - rho)
rho = [ldND; ldLM] / 100;   r = [s4ND; s4LM];
Rpk = sum(r .* (1 - rho)) / sum((1 - rho).^2);         % least squares
R2  = 1 - sum((r - Rpk*(1-rho)).^2) / sum((r - mean(r)).^2);
fprintf('Processor-sharing fit: Rpeak = %.1f Mbps, R^2 = %.3f\n', Rpk, R2);

figure('Name','Airtel diagnosis');
subplot(1,2,1);
scatter(ldND, 99.2*ones(size(ldND)), 18, [.6 .6 .6], 'filled'); hold on;
scatter(ldLM, succ, 22, [.89 0 0], 'filled');
xlabel('4G anchor (B3) load %'); ylabel('5G connection success %');
title('5G attach collapses at anchor saturation'); legend('Normal day','Last match','Location','southwest');
subplot(1,2,2);
scatter(rho*100, r, 18, [.89 0 0], 'filled'); hold on;
x = linspace(0,1,100); plot(x*100, Rpk*(1-x), 'k', 'LineWidth', 1.6);
xlabel('Anchor load % (\rho)'); ylabel('4G user speed (Mbps)');
title(sprintf('M/G/1-PS fit, R^2 = %.2f', R2));

% Final-day prediction: 1,00,000 fans, anchor capacity x8 (multi-anchor B1/B3/B40 + COWs + small cells)
growth = 100000/65000;  capRatio = 8;
Dfinal = DoverC * growth;
fprintf('Final, do nothing : 5G success %.1f %%\n', 100*min(1, 1/Dfinal));
fprintf('Final, our plan   : 5G success %.1f %%\n', 99.2*min(1, capRatio/Dfinal));
fprintf('Final, our plan   : 4G speed %.1f Mbps at rho = 0.76\n', Rpk*(1-0.76));

%% ---------------- Part B: M-QAM over Rayleigh ----------------
snrdB = 0:2:40;  N = 4e5;  Ms = [16 64 256];
figure('Name','M-QAM over Rayleigh');
cols = {[.6 .6 .6], [.13 .13 .13], [.89 0 0]};
for k = 1:numel(Ms)
    M = Ms(k); b = log2(M); ber = zeros(size(snrdB));
    for i = 1:numel(snrdB)
        bits = randi([0 1], N*b, 1);
        x  = qammod(bits, M, 'gray', 'InputType','bit', 'UnitAveragePower', true);
        h  = (randn(N,1) + 1j*randn(N,1)) / sqrt(2);         % flat Rayleigh
        y  = awgn(h .* x, snrdB(i), 'measured');
        xe = y ./ h;                                         % ideal CSI, ZF equaliser
        bh = qamdemod(xe, M, 'gray', 'OutputType','bit', 'UnitAveragePower', true);
        ber(i) = mean(bh ~= bits);
    end
    semilogy(snrdB, ber, 'o', 'Color', cols{k}); hold on;
    semilogy(snrdB, berfading(snrdB - 10*log10(b), 'qam', M, 1), '-', 'Color', cols{k}, 'LineWidth', 1.5);
    semilogy(snrdB, berawgn  (snrdB - 10*log10(b), 'qam', M),    '--','Color', cols{k});
end
grid on; ylim([1e-5 .5]); xlabel('Average SNR (dB)'); ylabel('BER');
title('M-QAM, flat Rayleigh: Monte Carlo vs theory (dashed = AWGN)');

%% ---------------- Part C: TR 36.942 A.2 link-to-system ----------------
% Thr = 0 for SINR < SINRmin; alpha*log2(1+SINR) up to the 256QAM ceiling
alpha = 0.75; SEmax = 7.4; SINRmin = -10;
sinr = -10:0.5:35; se = alpha*log2(1 + 10.^(sinr/10));
se(sinr < SINRmin) = 0; se = min(se, SEmax);
figure('Name','TR 36.942 mapping'); plot(sinr, se, 'r', 'LineWidth', 1.6); grid on;
xlabel('SINR (dB)'); ylabel('Spectral efficiency (b/s/Hz per layer)');
title('Attenuated & truncated Shannon (3GPP TR 36.942 A.2)');
