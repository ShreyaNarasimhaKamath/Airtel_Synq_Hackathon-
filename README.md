# Stadium Surge: Airtel Sync 2026, Network Track
Amritha S & Shreya Kamath, VIT Chennai

- `Airtel_Sync_Stadium_Surge.pptx` / `.pdf`: 7-slide submission (plus cover)
- `python/airtel_analysis.py Sync_V1.xlsx <outdir>`: diagnosis, current vs ours, M-QAM Rayleigh BER
- `python/stadium_reuse_sim.py`: seat-zone reuse system-level simulation (reuse-3 / FFR / reuse-1, crowd body loss)
- `matlab/stadium_surge.m`: the same analysis in MATLAB (Communications Toolbox)
- `matlab/SIMULINK_BUILD.md`: build the QAM-over-Rayleigh Simulink model
- `figures/`: all plots used in the deck

## Running
Place Airtel's case file `Sync_V1.xlsx` next to the scripts (not included in this repo), then:
```
pip install numpy scipy matplotlib openpyxl
python python/airtel_analysis.py Sync_V1.xlsx figures
python python/stadium_reuse_sim.py results.json
```
