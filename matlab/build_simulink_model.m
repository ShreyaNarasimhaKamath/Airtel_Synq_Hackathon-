function mdl = build_simulink_model(mdl)
%BUILD_SIMULINK_MODEL  Create and save stadium_link.slx (M-QAM over Rayleigh + AWGN).
%
%   Tx  -> Rayleigh + AWGN channel -> ZF equaliser + Gray demod -> running BER
%
%   Built only from core Simulink blocks and MATLAB Function blocks that call
%   sl_qam_mod / sl_rayleigh_awgn / sl_qam_bit_errors, so it needs MATLAB +
%   Simulink and no extra toolbox. Run once:  build_simulink_model
%   Then:  open_system('stadium_link')  or  run_simulink_ber
if nargin < 1, mdl = 'stadium_link'; end
if bdIsLoaded(mdl), close_system(mdl, 0); end
if exist([mdl '.slx'], 'file'), delete([mdl '.slx']); end
new_system(mdl);  open_system(mdl);
set_param(mdl, 'Solver', 'FixedStepDiscrete', 'FixedStep', 'Ts', 'StopTime', 'Tstop');

% workspace defaults (overridden by run_simulink_ber)
assignin('base', 'M', 256);  assignin('base', 'EsNo', 30);
assignin('base', 'Nframe', 1000);  assignin('base', 'Ts', 1e-3);  assignin('base', 'Tstop', 0.2);

blk = @(lib, name, pos) add_block(lib, [mdl '/' name], 'Position', pos);
blk('simulink/Sources/Constant', 'M',     [30  40  80  70]);   set_param([mdl '/M'],    'Value', 'M',    'SampleTime', 'Ts');
blk('simulink/Sources/Constant', 'Es/N0 (dB)', [30 150 80 180]); set_param([mdl '/Es/N0 (dB)'], 'Value', 'EsNo', 'SampleTime', 'Ts');
blk('simulink/User-Defined Functions/MATLAB Function', 'QAM Transmitter',     [140  30 270 110]);
blk('simulink/User-Defined Functions/MATLAB Function', 'Rayleigh + AWGN',     [330  30 460 190]);
blk('simulink/User-Defined Functions/MATLAB Function', 'ZF Equaliser + Demod',[520  30 660 190]);
blk('simulink/Sinks/Display',      'BER display', [730  40 850  80]);
blk('simulink/Sinks/To Workspace', 'ber_log',     [730 120 820 150]);
set_param([mdl '/ber_log'], 'VariableName', 'ber_log', 'SaveFormat', 'Array');
blk('simulink/Sinks/To Workspace', 'rx_symbols',  [730 200 820 230]);
set_param([mdl '/rx_symbols'], 'VariableName', 'rx_symbols', 'SaveFormat', 'Array');

set_script(mdl, 'QAM Transmitter', [ ...
    'function [x, sym] = fcn(M)' newline ...
    '%% Random symbols -> Gray M-QAM, unit average power' newline ...
    'N = 1000;' newline ...
    'sym = floor(rand(N, 1) * M);' newline ...
    'x = sl_qam_mod(sym, M);' newline]);
set_script(mdl, 'Rayleigh + AWGN', [ ...
    'function [y, h] = fcn(x, EsNo)' newline ...
    '%% Flat Rayleigh fading per symbol + AWGN at the given Es/N0 (or SINR)' newline ...
    '[y, h] = sl_rayleigh_awgn(x, EsNo);' newline]);
set_script(mdl, 'ZF Equaliser + Demod', [ ...
    'function [ber, z] = fcn(y, h, sym, M)' newline ...
    '%% Ideal-CSI zero-forcing equaliser, hard Gray demod, running BER' newline ...
    'persistent errs bits' newline ...
    'if isempty(errs), errs = 0; bits = 0; end' newline ...
    'z = y ./ h;' newline ...
    '[e, nb] = sl_qam_bit_errors(z, sym, M);' newline ...
    'errs = errs + e;  bits = bits + nb;' newline ...
    'ber = errs / max(bits, 1);' newline]);

ln = @(a, b) add_line(mdl, a, b, 'autorouting', 'on');
ln('M/1', 'QAM Transmitter/1');
ln('QAM Transmitter/1', 'Rayleigh + AWGN/1');
ln('Es/N0 (dB)/1', 'Rayleigh + AWGN/2');
ln('Rayleigh + AWGN/1', 'ZF Equaliser + Demod/1');
ln('Rayleigh + AWGN/2', 'ZF Equaliser + Demod/2');
ln('QAM Transmitter/2', 'ZF Equaliser + Demod/3');
ln('M/1', 'ZF Equaliser + Demod/4');
ln('ZF Equaliser + Demod/1', 'BER display/1');
ln('ZF Equaliser + Demod/1', 'ber_log/1');
ln('ZF Equaliser + Demod/2', 'rx_symbols/1');

annotate(mdl, ['Stadium Surge | link level: Gray M-QAM over flat Rayleigh + AWGN, ZF equaliser. ' ...
               'Set M and EsNo in the workspace, or run run_simulink_ber.m'], [30 230]);
save_system(mdl, [mdl '.slx']);
fprintf('Saved %s.slx\n', mdl);
end

function set_script(mdl, name, code)
rt = sfroot;
m  = rt.find('-isa', 'Simulink.BlockDiagram', 'Name', mdl);
ch = m.find('-isa', 'Stateflow.EMChart', 'Path', [mdl '/' name]);
ch.Script = code;
end

function annotate(mdl, txt, pos)
try
    a = Simulink.Annotation([mdl '/' txt]);
    a.Position = [pos pos + [600 20]];
catch
end
end
