function [nerr, nbits] = sl_qam_bit_errors(y, sym, M)
%SL_QAM_BIT_ERRORS  Hard-decision Gray M-QAM demod, count bit errors vs sym.
%   y : equalised received symbols (unit average power constellation)
m  = round(sqrt(M));  kb = round(log2(m));
y  = y * sqrt(2 * (M - 1) / 3);
ii = min(max(round((real(y) + m - 1) / 2), 0), m - 1);   % rail index
iq = min(max(round((imag(y) + m - 1) / 2), 0), m - 1);
gi = bitxor(ii, bitshift(ii, -1));  gq = bitxor(iq, bitshift(iq, -1));
ti = floor(sym / m);  tq = mod(sym, m);
nerr = popcount(bitxor(gi, ti), kb) + popcount(bitxor(gq, tq), kb);
nerr = sum(nerr);
nbits = numel(sym) * 2 * kb;
end

function c = popcount(v, kb)
c = zeros(size(v));
for k = 1:kb
    c = c + bitand(v, 1);  v = bitshift(v, -1);
end
end
