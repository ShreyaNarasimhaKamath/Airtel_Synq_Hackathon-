function r = reuse_sim_run(n_cells, scheme, crowd_db_per_m, seed, P)
%REUSE_SIM_RUN  Seat-zone small-cell layer in the stadium bowl, 3.5 GHz downlink.
%   scheme: 'reuse1' | 'reuse3' | 'ffr'
%   crowd_db_per_m: extra body loss per metre of path through the crowd
%                   (3GPP TR 38.901 sec 7.6.8 treats human blockage as extra loss)
if nargin < 5, P = reuse_params(); end
if nargin >= 4 && ~isempty(seed), set_seed(seed); end
[cells, col] = place_cells(n_cells, P);
ue = place_users(P.users, P);
dx = ue(:, 1) - cells(:, 1)';  dy = ue(:, 2) - cells(:, 2)';
d2 = sqrt(dx.^2 + dy.^2);
d  = max(sqrt(d2.^2 + P.h_diff^2), 1);
body = min(crowd_db_per_m * d2, 25);
pl = 32.4 + 20 * log10(P.f_ghz) + 31.9 * log10(d);          % UMi NLOS style
rx = 10 .^ ((P.ptx_dbm - pl - body) / 10);
[s, serv] = max(rx, [], 2);
noise = 10 ^ (P.noise_dbm / 10);
load_c = accumarray(serv, 1, [n_cells 1]);
n_u = load_c(serv);
tot = sum(rx, 2);
same = col(:)' == col(serv);                                   % same colour as serving cell
i_same = sum(rx .* same, 2) - s;
shan = @(g) P.layers * min(log2(1 + g), P.se_cap);
switch scheme
    case 'reuse1'
        sinr = s ./ (tot - s + noise);
        thr = P.bw * P.dl * shan(sinr) ./ n_u;
    case 'reuse3'
        sinr = s ./ (i_same + noise / 3);
        thr = P.bw / 3 * P.dl * shan(sinr) ./ n_u;
    case 'ffr'
        s1 = s ./ (tot - s + noise);
        edge = 10 * log10(s1) < P.edge_db;
        se_ = s ./ (i_same + noise);
        n_e = accumarray(serv, edge, [n_cells 1]);
        n_c = load_c - n_e;
        bc = P.bw * P.ffr_centre;  be = P.bw * (1 - P.ffr_centre) / 3;
        thr = zeros(size(s));
        thr(edge)  = be * P.dl * shan(se_(edge)) ./ max(n_e(serv(edge)), 1);
        thr(~edge) = bc * P.dl * shan(s1(~edge)) ./ max(n_c(serv(~edge)), 1);
        sinr = s1;  sinr(edge) = se_(edge);
    otherwise
        error('unknown scheme %s', scheme);
end
r.total_gbps = sum(thr) / 1e9;
r.pct_ok     = 100 * mean(thr >= P.target);
r.med_sinr   = median(10 * log10(sinr));
r.sinr_db    = 10 * log10(sinr);
end

function [xy, col] = place_cells(n, P)
rings = P.rings(:)';
per = round(n * rings / sum(rings));  per(end) = per(end) + n - sum(per);
xy = zeros(0, 2);  col = zeros(0, 1);
for k = 1:numel(rings)
    m = per(k);  a = ((0:m - 1)' + 0.5 * mod(k - 1, 2)) * 2 * pi / m;
    xy  = [xy; rings(k) * [cos(a) sin(a)]];             %#ok<AGROW>
    col = [col; mod((0:m - 1)' + k - 1, 3)];             %#ok<AGROW>
end
end

function ue = place_users(n, P)
r = sqrt(P.r_in^2 + (P.r_out^2 - P.r_in^2) * rand(n, 1));
a = 2 * pi * rand(n, 1);
ue = [r .* cos(a), r .* sin(a)];
end

function set_seed(seed)
if exist('OCTAVE_VERSION', 'builtin')
    rand('state', seed); randn('state', seed);
else
    rng(seed);
end
end
