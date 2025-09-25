% ----------- CLEAR -----------
clc; clear; close all;

% ----------- PHY / Radio SETTINGS -----------
fc    = 2.45e9;    % Carrier frequency
txgain = 10;       % RF gain
mcr   = 100e6;     % Master clock rate
fs    = 1e6;       % Baseband sample rate
sps   = 4;         % Samples per symbol (RRC)

% ======= TX Radio (Ethernet) =======
TX = comm.SDRuTransmitter( ...
    Platform            = "N200/N210/USRP2", ...
    IPAddress           = "192.168.10.5", ...   % <-- TX radio IP
    CenterFrequency     = fc, ...
    Gain                = txgain, ...
    ChannelMapping      = 1, ...
    InterpolationFactor = round(mcr/fs) ...     % integer
    );

% If you have a shared 10 MHz / PPS, uncomment:
% TX.ClockSource = "External";
% TX.PPSSource   = "External";

% ============== Build deterministic payload ==============
M = 4;                  % QAM order
symbolnum  = 400;       % payload symbols
preambleLen = 200;      % ZC preamble length (symbols)
u = 25; n = (0:preambleLen-1).';
zc_preamble = exp(-1j*pi*u*n.*(n+1)/preambleLen);  % Zadoff-Chu

% Deterministic data so RX can recreate it for SER:
rng(1337); 
txsymbols   = randi(M, symbolnum, 1) - 1;
txmodulated = qammod(txsymbols, M, 'UnitAveragePower', true);

% RRC TX filter
txfilter = comm.RaisedCosineTransmitFilter( ...
    OutputSamplesPerSymbol = sps, ...
    RolloffFactor          = 0.25 );

txdatasymbol = [zc_preamble; txmodulated];
txwave = txfilter([txdatasymbol; zeros(10,1)]); % flush
txwave = txwave ./ sqrt(mean(abs(txwave).^2));  % normalize power

% Repeat so the SDR buffer never under-runs
numRepeats = 10;
txBuf = repmat(txwave, numRepeats, 1);

% Optionally show what we're sending
scatterplot(txmodulated); title('TX Constellation');
scatterplot(txdatasymbol); title('Data and Preamble');
% ----------- Fire and forget -----------
Tsec = 12; % transmit duration
disp('TX host: starting transmission...');
tStart = tic;
while toc(tStart) < Tsec
    TX(txBuf);
end
disp('TX host: done.');

release(TX);