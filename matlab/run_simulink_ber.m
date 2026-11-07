function T = run_simulink_ber(sinr_points)
%RUN_SIMULINK_BER  Sweep the Simulink model and overlay it on theory.
%   Optional sinr_points: struct of scheme -> median SINR (dB) from the
%   stadium study, so each reuse scheme is also checked at link level.
mdl = 'stadium_link';
if ~exist([mdl '.slx'], 'file'), build_simulink_model(mdl); end
load_system(mdl);
snr = 0:4:40;  Ms = [16 64 256];  cols = {[.6 .6 .6], [.13 .13 .13], [.89 0 0]};
assignin('base', 'Ts', 1e-3);  assignin('base', 'Tstop', 0.2);   % 200 frames x 1000 symbols
T.snr = snr;  T.Ms = Ms;
fig = figure('Name', 'Simulink BER');
for k = 1:numel(Ms)
    assignin('base', 'M', Ms(k));
    for i = 1:numel(snr)
        assignin('base', 'EsNo', snr(i));
        out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
        b = out.get('ber_log');  T.ber(k, i) = b(end);
    end
    g = 10 .^ (snr / 10);  M = Ms(k);
    th = 2 / log2(M) * (1 - 1 / sqrt(M)) * (1 - sqrt(1.5 / (M - 1) * g ./ (1 + 1.5 / (M - 1) * g)));
    semilogy(snr, max(T.ber(k, :), 1e-7), 's', 'Color', cols{k}, 'MarkerFaceColor', cols{k}); hold on;
    semilogy(snr, th, '-', 'Color', cols{k}, 'LineWidth', 1.4);
end
grid on; ylim([1e-5 .5]); xlabel('Es/N0 (dB)'); ylabel('BER');
title('Simulink model (squares) vs Rayleigh theory (lines)');
legend('16-QAM Simulink', '16-QAM theory', '64-QAM Simulink', '64-QAM theory', '256-QAM Simulink', '256-QAM theory', 'Location', 'southwest');
print(fig, 'fig_simulink_ber.png', '-dpng', '-r200');
if nargin >= 1
    fn = fieldnames(sinr_points);
    assignin('base', 'M', 64);
    fprintf('\n== Link level at each scheme''s median SINR (64-QAM) ==\n');
    for j = 1:numel(fn)
        assignin('base', 'EsNo', sinr_points.(fn{j}));
        out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');  b = out.get('ber_log');
        fprintf('%-8s median SINR %5.1f dB -> BER %.4f\n', fn{j}, sinr_points.(fn{j}), b(end));
    end
end
end
