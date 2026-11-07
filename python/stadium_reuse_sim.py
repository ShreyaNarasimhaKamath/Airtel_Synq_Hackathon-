"""Stadium seat-zone frequency-reuse simulation (system level, downlink, 3.5 GHz n78).

Compares reuse-3, fractional frequency reuse (FFR) and full reuse-1 for an
under-seat small-cell layer, with and without crowd body attenuation.
"""
import numpy as np

rng = np.random.default_rng(7)

# ---------------- parameters ----------------
F_GHZ = 3.5
BW = 100e6            # n78 carrier
DL_SHARE = 0.74       # TDD DDDSU
LAYERS = 2            # 4T4R small cell, 2 layers per user
SE_CAP = 7.4          # bps/Hz per layer, 256QAM ceiling
PTX_DBM = 24.0        # small-cell power over 100 MHz
NOISE_DBM = -174 + 10 * np.log10(BW) + 7   # 7 dB UE noise figure
R_IN, R_OUT = 70.0, 130.0                  # seating bowl annulus (m)
H_DIFF = 0.7          # under-seat antenna (0.5 m) vs phone in hand (1.2 m)
USERS = 5040          # Airtel 5G users online at peak (28,000 x 18%)
TARGET = 5e6          # 5 Mbps per user
EDGE_SINR_DB = 5.0    # FFR: below this -> edge user
FFR_CENTRE = 0.5      # share of band reused everywhere for centre users


def pathloss_db(d):
    # 3GPP UMi street-canyon NLOS style; crowd adds extra loss separately
    return 32.4 + 20 * np.log10(F_GHZ) + 31.9 * np.log10(d)


def place_cells(n):
    rings = np.array([82.0, 100.0, 118.0])
    per = np.round(n * rings / rings.sum()).astype(int)
    per[-1] += n - per.sum()
    xy, colour = [], []
    for k, (r, m) in enumerate(zip(rings, per)):
        ang = (np.arange(m) + 0.5 * (k % 2)) * 2 * np.pi / m
        xy.append(np.c_[r * np.cos(ang), r * np.sin(ang)])
        colour.append((np.arange(m) + k) % 3)
    return np.vstack(xy), np.concatenate(colour)


def place_users(n):
    r = np.sqrt(rng.uniform(R_IN ** 2, R_OUT ** 2, n))
    a = rng.uniform(0, 2 * np.pi, n)
    return np.c_[r * np.cos(a), r * np.sin(a)]


def shannon(sinr_lin):
    return LAYERS * np.minimum(np.log2(1 + sinr_lin), SE_CAP)


def run(n_cells, scheme, crowd_db_per_m):
    cells, col = place_cells(n_cells)
    ue = place_users(USERS)
    d2 = np.linalg.norm(ue[:, None, :] - cells[None, :, :], axis=2)
    d = np.sqrt(d2 ** 2 + H_DIFF ** 2).clip(1.0)
    # crowd body loss grows with path length through the crowd, capped at 25 dB
    body = np.minimum(crowd_db_per_m * d2, 25.0)
    rx_dbm = PTX_DBM - pathloss_db(d) - body
    rx = 10 ** (rx_dbm / 10)
    serv = rx.argmax(1)
    s = rx[np.arange(USERS), serv]
    noise = 10 ** (NOISE_DBM / 10)
    load = np.bincount(serv, minlength=n_cells)
    n_u = load[serv]

    if scheme == "reuse1":
        sinr = s / (rx.sum(1) - s + noise)
        thr = BW * DL_SHARE * shannon(sinr) / n_u
    elif scheme == "reuse3":
        same = col[None, :] == col[serv][:, None]
        i = (rx * same).sum(1) - s
        sinr = s / (i + noise / 3)
        thr = BW / 3 * DL_SHARE * shannon(sinr) / n_u
    elif scheme == "ffr":
        sinr1 = s / (rx.sum(1) - s + noise)
        edge = 10 * np.log10(sinr1) < EDGE_SINR_DB
        same = col[None, :] == col[serv][:, None]
        sinr_e = s / ((rx * same).sum(1) - s + noise)
        # split users of each cell into centre / edge pools
        n_edge = np.bincount(serv, weights=edge, minlength=n_cells)
        n_cent = load - n_edge
        bc, be = BW * FFR_CENTRE, BW * (1 - FFR_CENTRE) / 3
        thr = np.where(
            edge,
            be * DL_SHARE * shannon(sinr_e) / np.maximum(n_edge[serv], 1),
            bc * DL_SHARE * shannon(sinr1) / np.maximum(n_cent[serv], 1),
        )
        sinr = np.where(edge, sinr_e, sinr1)
    else:
        raise ValueError(scheme)
    return dict(total_gbps=thr.sum() / 1e9,
                pct_ok=100 * (thr >= TARGET).mean(),
                p5_mbps=np.percentile(thr, 5) / 1e6,
                median_sinr_db=float(np.median(10 * np.log10(sinr))))


if __name__ == "__main__":
    import json, sys
    Ns = [12, 18, 24, 30, 36, 48, 60, 72, 96]
    out = {}
    for crowd in (0.0, 0.3):
        for sch in ("reuse3", "ffr", "reuse1"):
            key = f"{sch}|{crowd}"
            out[key] = {n: run(n, sch, crowd) for n in Ns}
            for n in Ns:
                r = out[key][n]
                print(f"{key:12s} N={n:3d} total={r['total_gbps']:6.2f} Gbps ok={r['pct_ok']:5.1f}% "
                      f"p5={r['p5_mbps']:6.2f} Mbps medSINR={r['median_sinr_db']:5.1f} dB")
    json.dump(out, open(sys.argv[1] if len(sys.argv) > 1 else "results.json", "w"))
