function P = reuse_params()
%REUSE_PARAMS  Stadium bowl and n78 small-cell parameters.
P.f_ghz = 3.5;  P.bw = 100e6;  P.dl = 0.74;        % TDD DDDSU
P.layers = 2;   P.se_cap = 7.4;                    % 4T4R, 256-QAM ceiling
P.ptx_dbm = 24; P.noise_dbm = -174 + 10 * log10(P.bw) + 7;
P.r_in = 70;    P.r_out = 130;  P.rings = [82 100 118];
P.h_diff = 0.7;                                    % under-seat antenna vs phone in hand
P.users = 5040;                                    % 28,000 Airtel 5G phones x 18% online
P.target = 5e6;
P.edge_db = 5;  P.ffr_centre = 0.5;
end
