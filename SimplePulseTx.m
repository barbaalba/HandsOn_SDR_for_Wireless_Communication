clear;clc;close all;
fc = 2.45e9; % carrier frequency
TX = comm.SDRuTransmitter('Platform','N200/N210/USRP2',...
    'CenterFrequency',fc,...
    'Gain',10,...
    'IPAddress','192.168.10.6');

% Create a waveform
dataSymbol = randi([0 1],64,1);
M = 2; % modulation order
txBB = pskmod(dataSymbol,M);
% Samples per symbol
sps = 16;
txBB = repelem(txBB,sps);

% Visualize the modulated symbols
scatterplot(txBB);
figure;
plot(real(txBB));
fs = 1e6; % frequency span (BW) of spectrum analyzer 
scope = spectrumAnalyzer(SampleRate = fs, ...
    FFTLength=1024,...
    YLimits=[-120,40],...
    Title = sprintf('USRP-2932 @ %.3f MHz', fc/1e6));

scope(txBB); % Visualize the spectrum of the pulse shape
release(scope); % let property values and input characteristics change

Tsec = 12; % transmit duration
disp('TX host: starting transmission...');
tStart = tic;
while toc(tStart) < Tsec
    TX(txBB);
end
disp('TX host: done.');
release(TX);