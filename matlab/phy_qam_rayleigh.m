function B = phy_qam_rayleigh(outdir, nsym)
%PHY_QAM_RAYLEIGH  Link level: 16/64/256-QAM over flat Rayleigh, Monte Carlo vs theory.
%   Uses the same sl_* functions as the Simulink model, so the two agree.
if nargin < 1, outdir = '.'; end
if nargin < 2, nsym = 2e5; end
snr = 0:2:40;  Ms = [16 64 256];
cols = {[.6 .6 .6], [.13 .13 .13], [.89 0 0]};
B.snr = snr;  B.Ms = Ms;
fig = figure('Name', 'M-QAM over Rayleigh');
for k = 1:numel(Ms)
    M = Ms(k);  g = 10 .^ (snr / 10);
    for i = 1:numel(snr)
        sym = randi([0 M - 1], nsym, 1);
        [y, h] = sl_rayleigh_awgn(sl_qam_mod(sym, M), snr(i));
        [e, nb] = sl_qam_bit_errors(y ./ h, sym, M);      % ideal CSI, ZF equaliser
        B.mc(k, i) = e / nb;
    end
    B.th_ray(k, :)  = ber_qam_rayleigh(M, g);
    B.th_awgn(k, :) = ber_qam_awgn(M, g);
    semilogy(snr, max(B.mc(k, :), 1e-7), 'o', 'Color', cols{k}); hold on;
    semilogy(snr, B.th_ray(k, :), '-', 'Color', cols{k}, 'LineWidth', 1.5);
    semilogy(snr, B.th_awgn(k, :), '--', 'Color', cols{k});
end
grid on; ylim([1e-5 .5]); xlabel('Average SNR (dB)'); ylabel('Bit error rate');
title('M-QAM, flat Rayleigh: Monte Carlo (o) vs theory (-), AWGN (--)');
legend('16-QAM MC', '16-QAM Rayleigh', '16-QAM AWGN', '64-QAM MC', '64-QAM Rayleigh', '64-QAM AWGN', ...
       '256-QAM MC', '256-QAM Rayleigh', '256-QAM AWGN', 'Location', 'southwest');
print(fig, fullfile(outdir, 'fig_phy_ber.png'), '-dpng', '-r200');
fprintf('\n== PHY ==\n256-QAM BER at 30 dB: MC %.4f, theory %.4f\n', B.mc(3, 16), B.th_ray(3, 16));
end

function p = ber_qam_awgn(M, g)
k = log2(M);
p = 4 / k * (1 - 1 / sqrt(M)) * 0.5 * erfc(sqrt(3 * g / (2 * (M - 1))));
end

function p = ber_qam_rayleigh(M, g)
k = log2(M);  a = 4 / k * (1 - 1 / sqrt(M));  b = 3 / (M - 1);
p = a / 2 * (1 - sqrt(b * g / 2 ./ (1 + b * g / 2)));
end
