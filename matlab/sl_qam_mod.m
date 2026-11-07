function x = sl_qam_mod(sym, M)
%SL_QAM_MOD  Gray-coded square M-QAM, unit average power.
%   Written with scalar arithmetic only, so it also runs inside a Simulink
%   MATLAB Function block (code generation) without any toolbox.
%   sym : integers 0..M-1   (upper half of the bits -> I, lower half -> Q)
m  = round(sqrt(M));
gi = floor(sym / m);  gq = mod(sym, m);           % Gray-coded rail indices
ai = 2 * gray2bin_vec(gi, m) - (m - 1);
aq = 2 * gray2bin_vec(gq, m) - (m - 1);
x  = complex(ai, aq) / sqrt(2 * (M - 1) / 3);
end

function b = gray2bin_vec(g, m)
b = g;  s = bitshift(g, -1);
for k = 1:ceil(log2(m))
    b = bitxor(b, s);  s = bitshift(s, -1);
end
end
