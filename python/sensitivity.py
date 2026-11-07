"""Sensitivity of our mix to the peak-online share and to spectral efficiency.

Idea from Shreya's notebook (15 / 18 / 25% online, several SE cases), applied
to the cells we actually propose: 12 existing + 12 COW 5G macro sectors,
20 existing + 12 COW 4G sectors, 24 under-seat small cells.
Prints the peak load on each layer (100% = cells full).
"""
AIRTEL, SHARE_5G = 40000, 0.70


def cap5(scale):  # Gbps at 100% load
    return (24 * 100 * 0.74 * 16 * scale + 24 * 100 * 0.74 * 7 * scale) / 1000


def cap4(scale):
    return (32 * 70 * 2.5 * scale + 24 * 40 * 3.0 * scale) / 1000


def table():
    rows = []
    for online in (0.15, 0.18, 0.25):
        d5 = AIRTEL * online * SHARE_5G * 5 / 1000
        d4 = AIRTEL * online * (1 - SHARE_5G) * 3 / 1000
        rows.append((online, d5, d4, [(100 * d5 / cap5(f), 100 * d4 / cap4(f)) for f in (1.0, 0.75, 0.6)]))
    return rows


if __name__ == "__main__":
    print("online  5G Gbps  4G Gbps   load 5G/4G at SE x1.0 | x0.75 | x0.6")
    for online, d5, d4, loads in table():
        print(f"{online:5.0%}  {d5:7.1f}  {d4:7.2f}   " + " | ".join(f"{a:4.0f}%/{b:4.0f}%" for a, b in loads))
    full4 = cap4(1.0) / (AIRTEL * (1 - SHARE_5G) * 3 / 1000)
    print(f"4G layer is full at {full4:.1%} online; 80% planning point at {0.8 * full4:.1%}")
