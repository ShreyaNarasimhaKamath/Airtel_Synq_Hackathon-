function se = tr36942_throughput(sinr_db, layers)
%TR36942_THROUGHPUT  3GPP TR 36.942 Annex A.2 attenuated & truncated Shannon.
%   se [b/s/Hz] = 0 below SINRmin, alpha*log2(1+SINR) up to the 256-QAM ceiling.
if nargin < 2, layers = 1; end
alpha = 0.75;  se_max = 7.4;  sinr_min = -10;
se = alpha * log2(1 + 10 .^ (sinr_db / 10));
se(sinr_db < sinr_min) = 0;
se = layers * min(se, se_max);
end
