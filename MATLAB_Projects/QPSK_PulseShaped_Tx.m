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
frameLen = 8192; % number of samples per TX SDR call (multiple of sps)
symbPerFrame = frameLen/sps;
framePerBuffer = 200; % How many frame should be in the host buffer
numSymbols = symbPerFrame*framePerBuffer;
data = randi([0 M-1],numSymbols,1);
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
scatterplot(qpsksymb);
figure;
plot(real(repelem(qpsksymb,sps)))
hold on;
plot(imag(repelem(qpsksymb,sps)),'--');
ylim([-2,2]);
figure;
plot(real(txsig(1:frameLen)));
hold on;
plot(imag(txsig(1:frameLen)));

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

Tsec = 60; % transmit duration
TxFrameCount = 1; % counter for tracking which frame being transmitted
underRuncount = 0; % To count underruns
txCallTimes = []; % To monitor and ensure underrun does not happen in my config
disp('TX host: starting transmission...');
tStart = tic;
while toc(tStart) < Tsec
    % undrrun happens when there is not enough data from host computer to 
    % SDR so SDR transmit zero and continuity of data is interupted so it
    % should be counted and reported.
    txFrame = txsig((TxFrameCount-1)*frameLen + (1:frameLen));
    tCall = tic;
    underRun = TX(txFrame); 
    txCallTimes(end+1) = toc(tCall);
    TxFrameCount = TxFrameCount +1;
    underRuncount = underRuncount + any(underRun);

    if TxFrameCount > framePerBuffer
        TxFrameCount = 1; % loop the buffer
    end
end
disp('TX host: done.');
fprintf('Underrun count: %d\n', underRuncount);
fprintf('TX call timing (seconds):\n');
fprintf('  Min:  %.6f\n', min(txCallTimes));
fprintf('  Mean: %.6f\n', mean(txCallTimes));
fprintf('  Max:  %.6f\n', max(txCallTimes));

release(TX);