# MATLAB and Simulink

Everything in the study, in MATLAB. The scripts also run in GNU Octave, except for the Simulink part.

```matlab
run_all            % full study, figures go to ./results
```

Put Airtel's `Sync_V1.xlsx` in this folder first (it is not committed).

| File | What it does |
|---|---|
| `run_all.m` | Runs every step in order and saves `results/stadium_surge_results.mat` |
| `load_airtel_data.m` | Reads the 8 sites × 4 match moments, plus the UPI table |
| `airtel_diagnosis.m` | Admission-cap test on the n78 sites (success = C/D), M/G/1-PS speed fit, UPI fit |
| `current_vs_ours.m` | Last match (measured) vs final with the plan (predicted) |
| `phy_qam_rayleigh.m` | 16/64/256-QAM over flat Rayleigh: Monte Carlo vs closed form |
| `reuse_params.m`, `reuse_sim_run.m` | Seat-zone small-cell layer: reuse-3 / FFR / reuse-1 with crowd body loss |
| `stadium_reuse_study.m` | Capacity vs cell count, and the FFR → reuse-1 crossover sweep |
| `sensitivity_check.m` | Peak load of the proposed cells vs online share and SE |
| `tr36942_throughput.m` | 3GPP TR 36.942 A.2 SINR → spectral-efficiency mapping |
| `sl_qam_mod.m`, `sl_rayleigh_awgn.m`, `sl_qam_bit_errors.m` | Link-level building blocks, shared by the scripts and the Simulink model |
| `build_simulink_model.m` | Builds and saves `stadium_link.slx` |
| `run_simulink_ber.m` | Sweeps the Simulink model and overlays Rayleigh theory |

## Simulink model `stadium_link.slx`

```matlab
build_simulink_model          % creates stadium_link.slx in this folder
open_system('stadium_link')
run_simulink_ber              % BER sweep, 16/64/256-QAM, 0-40 dB
```

```
 [M] ──► QAM Transmitter ──x──► Rayleigh + AWGN ──y,h──► ZF Equaliser + Demod ──BER──► Display / ber_log
               │ sym            ▲ Es/N0 (dB)                    ▲ sym, M                └─z──► rx_symbols
               └────────────────┼────────────────────────────────┘
```

- **QAM Transmitter:** 1,000 random symbols per frame, Gray-coded square M-QAM, unit average power.
- **Rayleigh + AWGN:** one complex Gaussian tap per symbol (E|h|² = 1), then noise at the set Es/N0. In the system study, the same block is driven at each reuse scheme's median SINR.
- **ZF Equaliser + Demod:** divides by h (ideal CSI), makes hard Gray decisions and accumulates the bit-error rate.

The blocks are MATLAB Function blocks that call the `sl_*.m` files, so the model needs only MATLAB and Simulink, with no extra toolbox. `run_all` builds it and checks each reuse scheme at link level, when Simulink is licensed.
