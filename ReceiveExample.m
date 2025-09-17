clc;clear;close all;
% ----------- Module SETTINGS -----------
USRP_num =   2;
ip       = "192.168.10.5,192.168.10.4"; 
fc       = 2.45e9;      % Carrier frequency
chmap    = 1:USRP_num;  % Channel mapping for multiple blundled SDRs
gain     = 20;          % RF  gain
decim    = 512;         % decimation (100e6/512 ≈ 195.3125 kS/s)
Tsec     = 5;           % capture duration (seconds)
mimoflag = false;

% ======= Capture N seconds =======
[data,Fs] = usrp_receive(ip,repelem(fc,1,USRP_num),repelem(gain,1,USRP_num),decim,Tsec,chmap,mimoflag);

% ======= Visualize spectrum =======
scope = spectrumAnalyzer(SampleRate = Fs, ...
                             Title = sprintf('USRP-2932 @ %.3f MHz', fc/1e6));
scope(data);

% ======= Cleanup =======
release(scope);

xc = xcorr(data(:,1), data(:,2));
[~,k] = max(abs(xc));
lag_samps = k - numel(data(:,1));
lag_sec   = lag_samps/Fs;
fprintf("Estimated inter-radio lag: %.3g samples (%.3g us)\n", ...
        lag_samps, 1e6*lag_sec);