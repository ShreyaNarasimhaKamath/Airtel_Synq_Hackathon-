%% Stadium Surge | Airtel Sync 2026, Network Track
% Amritha S, Shreya Kamath | VIT Chennai
%
% Runs the full study. Put Airtel's Sync_V1.xlsx in this folder first.
%   1. Diagnosis on Airtel's counters      (airtel_diagnosis)
%   2. Current vs ours at the final        (current_vs_ours)
%   3. Link level: M-QAM over Rayleigh     (phy_qam_rayleigh)
%   4. System level: seat-zone reuse       (stadium_reuse_study)
%   5. TR 36.942 link-to-system mapping    (tr36942_throughput)
%   6. Simulink model + sweep              (build_simulink_model, run_simulink_ber)
clear; close all; clc;
out = 'results';  if ~exist(out, 'dir'), mkdir(out); end

D = load_airtel_data('Sync_V1.xlsx');
R = airtel_diagnosis(D, out);

% our plan: anchor capacity x8 (B1/B3/B40 anchors on 20 + 12 COW sectors, 24 small cells)
plan.anchor_ratio = (20 * 70/20 + 12 * 70/20 + 24 * 40/20) / 20;
plan.rho4 = 0.80 * 6.48 / 6.78;      % 4G demand / 4G capacity at 80% planning load
plan.rho5 = 0.80 * 25.2 / 32.68;     % 5G demand / 5G capacity
plan.upi_now = D.upi_lm;
P = current_vs_ours(R, plan, out);

B = phy_qam_rayleigh(out);
S = stadium_reuse_study(out);

fig = figure('Name', 'TR 36.942');
s = -10:0.5:35;  plot(s, tr36942_throughput(s), 'r', 'LineWidth', 1.6); grid on;
xlabel('SINR (dB)'); ylabel('b/s/Hz per layer'); title('3GPP TR 36.942 A.2 mapping');
print(fig, fullfile(out, 'fig_tr36942.png'), '-dpng', '-r200');

if exist('OCTAVE_VERSION', 'builtin') == 0 && license('test', 'Simulink')
    build_simulink_model('stadium_link');
    med.reuse3 = 0; med.ffr = 0; med.reuse1 = 0;
    for f = fieldnames(med)'
        t = reuse_sim_run(24, f{1}, 0.3, 7);  med.(f{1}) = t.med_sinr;
    end
    run_simulink_ber(med);
end
save(fullfile(out, 'stadium_surge_results.mat'), 'R', 'P', 'B', 'S');
