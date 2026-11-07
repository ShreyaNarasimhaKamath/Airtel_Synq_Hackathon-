function [y, h] = sl_rayleigh_awgn(x, snr_db)
%SL_RAYLEIGH_AWGN  Flat Rayleigh fading (one tap per symbol) plus AWGN.
%   E|h|^2 = 1, Es = 1, so snr_db is the average Es/N0 (or SINR when the
%   interference is treated as Gaussian, as in the system-level model).
n  = numel(x);
h  = complex(randn(n, 1), randn(n, 1)) / sqrt(2);
n0 = 10 ^ (-snr_db / 10);
w  = sqrt(n0 / 2) * complex(randn(n, 1), randn(n, 1));
y  = h .* x(:) + w;
end
