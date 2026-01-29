clear;clc;close all;
% -------- USRP/SDR config ---------
fc = 2.45e9; % carrier frequency
usrpInterp = 32; % USRP interpolation factor 
usrpMasterClk = 100e6; % USRP master clock in Hz
samplesRate = usrpMasterClk/usrpInterp;
sps = 4; % samples per symbol 
alpha = 0.25; % rolloff for RRC filter
Rs = samplesRate/sps; % symbol rate
BW = Rs*(1+alpha); % Target occupied bandwidth
fprintf('Approx occupied BW = %.6f MHz\n', BW/1e6);

% -------- QPSK pulse shaping --------

M = 4; % PSK order
data = randi([0 M-1],Rs,1);
qpsksymb = pskmod(data,M,pi/4);

% Pulse shaping with RRC
txPulseShape = comm.RaisedCosineTransmitFilter(Shape="Square root",...
    RolloffFactor = alpha,...
    OutputSamplesPerSymbol=sps,...
    FilterSpanInSymbols = 11);
% To ensure that the pass band gain eqaul to 1 
b = coeffs(txPulseShape);
txPulseShape.Gain = 1/sum(b.Numerator);

txsig = txPulseShape(qpsksymb);

%------- Visualization of the symbols and pulse shaped signal ------
% scatterplot(qpsksymb);
% figure;
% plot(real(repelem(qpsksymb,sps)))
% hold on;
% plot(imag(repelem(qpsksymb,sps)),'--');
% ylim([-2,2]);
% figure;
% plot(real(txsig));
% hold on;
% plot(imag(txsig));

%------- Spectrum of the signal ----------
scope = spectrumAnalyzer(SampleRate=samplesRate,...
    YLimits=[-120,40],...
    Title=sprintf("QPSK RRC: Rs=%.3f ksym/s, Fs=%.3f MS/s, alpha=%.2f", Rs/1e3, samplesRate/1e6, alpha));
scope(txsig);


release(scope);
release(txPulseShape);

% ------- Transmission of the signal over the air -------
TX = comm.SDRuTransmitter('Platform','N200/N210/USRP2',...
    'CenterFrequency',fc,...
    'Gain',10,...
    'IPAddress','192.168.10.6',...
    'MasterClockRate',usrpMasterClk,...
    'InterpolationFactor', usrpInterp);

Tsec = 12; % transmit duration
underRuncount = 0; % To count underruns
txCallTimes = []; % To monitor and ensure underrun does not happen in my config
disp('TX host: starting transmission...');
tStart = tic;
while toc(tStart) < Tsec
    tCall = tic;
    % undrrun happens when there is not enough data from host computer to 
    % SDR so SDR transmit zero and continuity of data is interupted so it
    % should be counted and reported.
    underRun = TX(txsig); % With my configuration the air time is exactly 1 second
    txCallTimes(end+1) = toc(tCall);
    underRuncount = underRuncount + any(underRun);
end
disp('TX host: done.');
fprintf('Underrun count: %d\n', underRuncount);
fprintf('TX call timing (seconds):\n');
fprintf('  Min:  %.6f\n', min(txCallTimes));
fprintf('  Mean: %.6f\n', mean(txCallTimes));
fprintf('  Max:  %.6f\n', max(txCallTimes));

release(TX);