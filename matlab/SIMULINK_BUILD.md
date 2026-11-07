# Simulink model: M-QAM over Rayleigh fading (about 15 minutes to build)

Build this yourselves and take the screenshot from your own machine. It matches Part B of `stadium_surge.m`.

## Blocks (search for these names in the Library Browser)

| # | Block | Library | Settings |
|---|---|---|---|
| 1 | Random Integer Generator | Communications Toolbox › Comm Sources | Set size M = 256, Sample time 1e-6, Samples per frame 1000 |
| 2 | Rectangular QAM Modulator Baseband (called *QAM Modulator Baseband* in newer releases) | Modulation › Digital Baseband › AM | M = 256, Gray, Normalization: Average Power = 1 |
| 3 | SISO Fading Channel | Channels | Fading distribution Rayleigh, Discrete path delays 0, Average path gains 0 dB, Max Doppler 5 Hz (pedestrian at 3.5 GHz), tick "Output channel path gains" |
| 4 | AWGN Channel | Channels | Mode: Signal to noise ratio (Es/No), Es/No = variable `EsNo`, Input signal power 1 W |
| 5 | Product (set to `*/`) | Simulink › Math Operations | Divide the received signal by the path gain from block 3 (ideal-CSI equaliser) |
| 6 | Rectangular QAM Demodulator Baseband | Modulation › Digital Baseband › AM | Same M, Gray, Average Power = 1, Output: Integer |
| 7 | Integer to Bit Converter ×2 | Utility Blocks | 8 bits per integer (for 256-QAM) |
| 8 | Error Rate Calculation | Comm Sinks | Output data: Port |
| 9 | Display | Simulink › Sinks | Shows [BER, errors, bits] |
| 10 | Constellation Diagram | Comm Sinks | Connect after block 5 to show the faded constellation |

Wiring: 1 → 2 → 3 (signal) → 4 → 5 (numerator); 3 (path gain) → 5 (denominator); 5 → 6 → 7 → 8 (Rx); 1 → 7 → 8 (Tx); 8 → 9.

## Sweeping SNR
Set `EsNo = 20;` in the workspace and run. To get a curve, run from MATLAB:
```matlab
EsNoVec = 0:4:40; ber = zeros(size(EsNoVec));
for i = 1:numel(EsNoVec)
    EsNo = EsNoVec(i); out = sim('qam_rayleigh', 'StopTime', '0.5');
    ber(i) = out.simout.Data(end,1);   % add a To Workspace block named simout after Error Rate Calculation
end
semilogy(EsNoVec, ber, 'o-'); grid on
```
Repeat with M = 16 and 64 (2 and 6 bits per integer in block 7). Your curves should sit on the `berfading` lines from the script.

## What to say about it
- At the innings break, measured 5G speed fell from about 139 to 12 Mbps. Interference pushes the received SINR down, so link adaptation falls from 256-QAM to 16-QAM or QPSK. The Rayleigh curves show the 25–30 dB SNR that 256-QAM needs for a usable BER.
- Crowd shielding plus under-seat cells raises SINR, which lets more users stay on higher-order QAM. That is the physical-layer reason the capacity gain in our system-level simulation exists.
