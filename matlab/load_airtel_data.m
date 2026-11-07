function D = load_airtel_data(path)
%LOAD_AIRTEL_DATA  Read Airtel's Sync_V1.xlsx (stadium sites x match moments).
%   D = load_airtel_data('Sync_V1.xlsx') returns a struct with per-row
%   site, phase, anchor load (normal / last match), 4G and 5G user speed,
%   5G connection success, and the UPI failure table.
%   A .mat file with the same fields is also accepted.
if numel(path) > 4 && strcmpi(path(end-3:end), '.mat')
    D = load(path); return;
end
C = readcell(path, 'Range', 'A3:J34');
U = readcell(path, 'Range', 'L14:N17');
num = @(c) cellfun(@(v) double_or_nan(v), c);
D.site    = cellfun(@char, C(:,1), 'UniformOutput', false);
D.phase   = cellfun(@char, C(:,2), 'UniformOutput', false);
D.ld_nd   = num(C(:,4));   D.ld_lm = num(C(:,5));
D.s4_nd   = num(C(:,6));   D.s4_lm = num(C(:,7));
D.s5_nd   = num(C(:,8));   D.s5_lm = num(C(:,9));
D.succ    = num(C(:,10));
D.upi_t   = cellfun(@char, U(:,1), 'UniformOutput', false);
D.upi_lm  = num(U(:,2));   D.upi_nd = num(U(:,3));
end

function v = double_or_nan(x)
if isnumeric(x) && ~isempty(x), v = double(x); else, v = NaN; end
end
