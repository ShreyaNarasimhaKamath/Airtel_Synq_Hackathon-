function T = sensitivity_check()
%SENSITIVITY_CHECK  Peak load of our mix vs online share and spectral efficiency.
%   Idea from Shreya's notebook, applied to the proposed cells.
airtel = 40000;  s5 = 0.70;
cap5 = @(f) (24 * 100 * 0.74 * 16 * f + 24 * 100 * 0.74 * 7 * f) / 1000;
cap4 = @(f) (32 * 70 * 2.5 * f + 24 * 40 * 3.0 * f) / 1000;
online = [0.15 0.18 0.25];  se = [1 0.75 0.6];
fprintf('\n== Sensitivity (peak load 5G / 4G) ==\n');
for i = 1:3
    d5 = airtel * online(i) * s5 * 5 / 1000;  d4 = airtel * online(i) * (1 - s5) * 3 / 1000;
    fprintf('%3.0f%% online:', 100 * online(i));
    for j = 1:3
        T(i, j, 1) = 100 * d5 / cap5(se(j));  T(i, j, 2) = 100 * d4 / cap4(se(j));
        fprintf('  SE x%.2f %4.0f%% / %4.0f%%', se(j), T(i, j, 1), T(i, j, 2));
    end
    fprintf('\n');
end
end
