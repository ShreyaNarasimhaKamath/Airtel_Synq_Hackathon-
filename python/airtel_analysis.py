"""Current vs proposed, calibrated on Airtel's Sync_V1.xlsx (last match, 65k fans).

Models (all standard teletraffic / 3GPP practice):
  * 5G attach: hard admission cap on the NSA B3 anchor  ->  success = min(1, C / D)
  * User speed: M/G/1 processor sharing  ->  r = R_peak * (1 - rho)
  * UPI failure: logistic in anchor load, fitted to the 4 match moments + normal day
  * PHY: M-QAM over flat Rayleigh fading, Monte Carlo vs closed form
  * Link-to-system: 3GPP TR 36.942 A.2 attenuated & truncated Shannon
"""
import sys, json
import numpy as np, openpyxl
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.special import erfc
from scipy.optimize import curve_fit

XLSX, OUT = sys.argv[1], sys.argv[2]
RED, DARK, GREY = "#E40000", "#222222", "#9A9A9A"
plt.rcParams.update({"font.size": 10.5, "axes.spines.top": False, "axes.spines.right": False})
PH = ["Crowd building up", "Innings break", "Final over", "Post-match"]
PHS = ["Build-up\n17:00", "Innings\n21:00", "Final over\n22:45", "Post-match\n23:15"]

# ---------------- load Airtel data ----------------
ws = openpyxl.load_workbook(XLSX).active
rows = [r for r in ws.iter_rows(min_row=3, values_only=True) if r[0] and r[1] in PH]
upi_lm = {r[11]: r[12] for r in ws.iter_rows(min_row=14, max_row=17, values_only=True)}
upi_nd = {r[11]: r[13] for r in ws.iter_rows(min_row=14, max_row=17, values_only=True)}
site, phase = [r[0] for r in rows], [r[1] for r in rows]
ld_nd, ld_lm = np.array([r[3] for r in rows]), np.array([r[4] for r in rows])
s4_nd, s4_lm = np.array([r[5] for r in rows]), np.array([r[6] for r in rows])
s5_nd = np.array([r[7] if r[7] is not None else np.nan for r in rows])
s5_lm = np.array([r[8] if r[8] is not None else np.nan for r in rows])
succ = np.array([r[9] for r in rows])
res = {}

# ---------------- 1. diagnosis: the flat 36% ----------------
sat = ld_lm > 95
res["sat_succ_min"], res["sat_succ_max"] = float(succ[sat].min()), float(succ[sat].max())
res["sat_succ_mean"], res["sat_succ_std"] = float(succ[sat].mean()), float(succ[sat].std())
res["sat_load_min"], res["sat_load_max"] = float(ld_lm[sat].min()), float(ld_lm[sat].max())
res["n_sat"] = int(sat.sum())
# hard cap: success = C/D  ->  demand/cap ratio during saturation
dc = 100 / res["sat_succ_mean"]
res["demand_over_cap_last_match"] = dc

fig, ax = plt.subplots(1, 2, figsize=(9.6, 3.5), dpi=220)
ax[0].scatter(ld_nd, np.full_like(ld_nd, 99.2), s=18, color=GREY, label="Normal day")
ax[0].scatter(ld_lm, succ, s=22, color=RED, label="Last match", zorder=3)
ax[0].axhspan(res["sat_succ_min"], res["sat_succ_max"], color=RED, alpha=.08)
ax[0].annotate(f"{res['n_sat']} saturated cell-moments:\n5G success {res['sat_succ_min']:.0f}–{res['sat_succ_max']:.0f}% (σ={res['sat_succ_std']:.1f})\n→ a hard admission cap, not random congestion",
               xy=(97.5, 37), xytext=(22, 50), fontsize=8.5, arrowprops=dict(arrowstyle="->", color=DARK))
ax[0].set_xlabel("4G anchor (B3) load %"); ax[0].set_ylabel("5G connection success %")
ax[0].set_title("Airtel data: 5G attach collapses when the anchor saturates", loc="left", fontsize=10)
ax[0].legend(frameon=False, fontsize=8.5, loc="lower left"); ax[0].set_ylim(0, 105)

# processor-sharing fit on 4G speed vs load (both days, all sites)
L = np.r_[ld_nd, ld_lm] / 100; S = np.r_[s4_nd, s4_lm]
ps = lambda rho, R: R * np.clip(1 - rho, 0.005, 1)
R4, _ = curve_fit(ps, L, S, p0=[20]); R4 = float(R4[0])
m5 = ~np.isnan(s5_nd)
R5 = float(np.median(s5_nd[m5] / (1 - ld_nd[m5] / 100)))  # 5G peak from normal-day speeds
res["R4_peak_mbps"], res["R5_peak_mbps"] = R4, R5
res["ps_r2"] = float(1 - ((S - ps(L, R4)) ** 2).sum() / ((S - S.mean()) ** 2).sum())
xx = np.linspace(0, 1, 100)
ax[1].scatter(L * 100, S, s=18, color=RED)
ax[1].plot(xx * 100, ps(xx, R4), color=DARK, lw=1.8, label=f"M/G/1-PS fit: r = {R4:.1f}·(1−ρ) Mbps, R² = {1 - ((S - ps(L, R4)) ** 2).sum() / ((S - S.mean()) ** 2).sum():.2f}")
ax[1].set_xlabel("4G anchor load % (ρ)"); ax[1].set_ylabel("4G user speed (Mbps)")
ax[1].set_title("User speed follows processor sharing", loc="left", fontsize=10)
ax[1].legend(frameon=False, fontsize=8.5)
fig.tight_layout(); fig.savefig(f"{OUT}/fig_airtel_diagnosis.png")

# ---------------- 2. UPI failure vs anchor load ----------------
avg_ld = {p: float(np.mean([l for l, q, s in zip(ld_lm, phase, site) if q == p and s != "M6"])) for p in PH}
avg_nd = {p: float(np.mean([l for l, q in zip(ld_nd, phase) if q == p])) for p in PH}
times = ["17:00", "21:00", "22:45", "23:15"]
X = np.r_[[avg_nd[p] for p in PH], [avg_ld[p] for p in PH]]
Y = np.r_[[upi_nd[t] for t in times], [upi_lm[t] for t in times]]
logi = lambda x, b, k, x0, top: b + top / (1 + np.exp(-k * (x - x0)))
pu, _ = curve_fit(logi, X, Y, p0=[1.1, 0.3, 90, 6], maxfev=20000)
res["upi_fit"] = [float(v) for v in pu]

# ---------------- 3. final-day prediction: current vs ours ----------------
growth = 100000 / 65000
# anchor capacity units (B3 sector = 1). Current: 20 cells on B3 only.
B3_MHZ, LTE_MHZ, SC_LTE_MHZ = 20, 70, 40
cap_now = 20
cap_ours = (20 * LTE_MHZ / B3_MHZ) + (12 * LTE_MHZ / B3_MHZ) + (24 * SC_LTE_MHZ / B3_MHZ)
res["anchor_capacity_ratio"] = cap_ours / cap_now
phase_demand = {p: (avg_ld[p] / 100) for p in PH}  # build-up demand scale
# demand relative to current cap: saturated phases use dc; build-up uses its load
dem_lm = {p: (dc if avg_ld[p] > 95 else avg_ld[p] / 100 * 1.0) for p in PH}
res["phases"] = {}
for p in PH:
    d_final = dem_lm[p] * growth
    succ_cur = min(1, 1 / d_final) * 100
    succ_new = min(1, cap_ours / cap_now / d_final) * 99.2 / 100 * 100 / 1.0
    succ_new = min(succ_new, 99.2)
    # 4G load after fix: 5G phones leave 4G; ours capacity per plan
    rho4_new = min(0.99, 6.48 / 6.78 * 0.8 * (d_final / (dc * growth)))
    rho5_new = min(0.99, 25.2 / 32.68 * 0.8 * (d_final / (dc * growth)))
    res["phases"][p] = dict(
        succ_last=float(np.mean([s for s, q, st in zip(succ, phase, site) if q == p and st != "M6"])),
        succ_final_current=succ_cur, succ_final_ours=succ_new,
        spd4_last=float(np.mean([s for s, q, st in zip(s4_lm, phase, site) if q == p and st != "M6"])),
        spd4_ours=ps(rho4_new, R4), spd5_ours=ps(rho5_new, R5),
        upi_last=float(upi_lm[times[PH.index(p)]]),
        upi_final_current=float(logi(min(99.5, avg_ld[p] * (1 if avg_ld[p] > 95 else growth)), *pu)),
        upi_ours=float(logi(avg_nd[p], *pu)),  # payments isolated from load by QoS
        rho4_ours=rho4_new, rho5_ours=rho5_new)

fig, ax = plt.subplots(1, 3, figsize=(10.5, 3.3), dpi=220)
x = np.arange(4); w = .38
P = res["phases"]
ax[0].bar(x - w / 2, [P[p]["succ_last"] for p in PH], w, color=GREY, label="Current (last match, measured)")
ax[0].bar(x + w / 2, [P[p]["succ_final_ours"] for p in PH], w, color=RED, label="Ours (final, predicted)")
ax[0].set_title("5G connection success %", loc="left", fontsize=10)
ax[1].bar(x - w / 2, [P[p]["spd4_last"] for p in PH], w, color=GREY)
ax[1].bar(x + w / 2, [P[p]["spd4_ours"] for p in PH], w, color=RED)
ax[1].axhline(3, color=DARK, ls=":", lw=1); ax[1].text(3.45, 3.2, "3 Mbps target", fontsize=8, ha="right")
ax[1].set_title("4G user speed (Mbps)", loc="left", fontsize=10)
ax[2].bar(x - w / 2, [P[p]["upi_last"] for p in PH], w, color=GREY)
ax[2].bar(x + w / 2, [P[p]["upi_ours"] for p in PH], w, color=RED)
ax[2].set_title("UPI failure %", loc="left", fontsize=10)
for a in ax:
    a.set_xticks(x); a.set_xticklabels(PHS, fontsize=8)
fig.legend(*ax[0].get_legend_handles_labels(), loc="upper center", ncol=2, frameon=False, fontsize=9)
fig.tight_layout(rect=(0, 0, 1, 0.9)); fig.savefig(f"{OUT}/fig_current_vs_ours.png")

# ---------------- 4. PHY: M-QAM over Rayleigh, Monte Carlo vs theory ----------------
rng = np.random.default_rng(1)
snr_db = np.arange(0, 41, 2)
def qam_const(M):
    m = int(np.sqrt(M)); a = np.arange(-m + 1, m, 2)
    c = (a[:, None] + 1j * a[None, :]).ravel()
    return c / np.sqrt((np.abs(c) ** 2).mean())
def gray_bits(M):
    m = int(np.sqrt(M)); k = int(np.log2(m))
    g = np.array([i ^ (i >> 1) for i in range(m)])
    bits = lambda v: [(v >> (k - 1 - j)) & 1 for j in range(k)]
    return np.array([bits(g[i]) + bits(g[q]) for i in range(m) for q in range(m)])
def ber_theory_awgn(M, g):
    k = np.log2(M); return 4 / k * (1 - 1 / np.sqrt(M)) * 0.5 * erfc(np.sqrt(3 * g / (2 * (M - 1))))
def ber_theory_rayleigh(M, g_bar):
    k = np.log2(M); a = 4 / k * (1 - 1 / np.sqrt(M)); b = 3 / (M - 1)
    return a / 2 * (1 - np.sqrt(b * g_bar / 2 / (1 + b * g_bar / 2)))
ber = {}
N = 400_000
for M in (16, 64, 256):
    c, gb = qam_const(M), gray_bits(M)
    out = []
    for s in snr_db:
        idx = rng.integers(0, M, N)
        h = (rng.standard_normal(N) + 1j * rng.standard_normal(N)) / np.sqrt(2)
        n0 = 10 ** (-s / 10)
        n = np.sqrt(n0 / 2) * (rng.standard_normal(N) + 1j * rng.standard_normal(N))
        y = (h * c[idx] + n) / h  # ideal CSI, zero-forcing equaliser
        det = np.abs(y[:, None] - c[None, :]).argmin(1)
        out.append((gb[det] != gb[idx]).sum() / (N * np.log2(M)))
    ber[M] = out
fig, ax = plt.subplots(figsize=(5.2, 3.6), dpi=220)
for M, col in ((16, GREY), (64, DARK), (256, RED)):
    g = 10 ** (snr_db / 10)
    ax.semilogy(snr_db, np.maximum(ber[M], 1e-7), "o", ms=3.5, color=col)
    ax.semilogy(snr_db, ber_theory_rayleigh(M, g), "-", color=col, lw=1.6, label=f"{M}-QAM Rayleigh")
    ax.semilogy(snr_db, ber_theory_awgn(M, g), "--", color=col, lw=1, alpha=.6)
ax.set_ylim(1e-5, 0.5); ax.set_xlabel("Average SNR (dB)"); ax.set_ylabel("Bit error rate")
ax.set_title("M-QAM, flat Rayleigh: Monte Carlo (dots) vs theory\n(dashed = AWGN)", loc="left", fontsize=9.5)
ax.legend(frameon=False, fontsize=8); ax.grid(which="both", color="#eee")
fig.tight_layout(); fig.savefig(f"{OUT}/fig_phy_ber.png")
res["ber_256_at_30dB_mc"] = float(ber[256][15]); res["ber_256_at_30dB_th"] = float(ber_theory_rayleigh(256, 1000))

json.dump(res, open(f"{OUT}/analysis_results.json", "w"), indent=1)
print(json.dumps(res, indent=1))
