clc;clear;close all;
% ----------- Module SETTINGS -----------
fc       = 2.45e9;      % Carrier frequency
txgain     = 10;         % RF  gain
rxgain     = 20;         % RF gain
decim    = 512;         % decimation (100e6/512 ≈ 195.3125 kS/s)
Tsec     = 12;          % capture duration (seconds)
mcr = 100e6;            %  master clock rate is the analog to digital (A/D) and digital to analog (D/A) clock rate
fs = 1e6;               % Effective base band sampling rate for up and down sampling

% ======= TX Radio configuration (Ethernet) =======
TX = comm.SDRuTransmitter(...
    Platform            = "N200/N210/USRP2",...
    IPAddress           = "192.168.10.5",...
    CenterFrequency     = fc,...
    Gain                = txgain,...
    ChannelMapping      = 1,...
    InterpolationFactor = round(mcr/fs) ...     % It should be integer value
    );

% ======= RX Radio configuration (Ethernet) =======
RX = comm.SDRuReceiver(...
    Platform            = "N200/N210/USRP2",...
    IPAddress           = "192.168.10.4",...
    CenterFrequency     = fc,...
    ChannelMapping      = 1,...
    Gain                = rxgain,...
    DecimationFactor    = round(mcr/fs),...
    OutputDataType      = "double",...
    SamplesPerFrame     = 8192 ...
    );

% ============== Tx signal ==============
M = 4;             % Which QAM modulation
symbolnum = 800;    % number of QAM symbold
totalbitLength = symbolnum * log2(M);
txsymbols = randi(M,symbolnum,1)-1; % it should be column vector
txmodulated = qammod(txsymbols,M,'UnitAveragePower',true);
scatterplot(txmodulated);

% make preamble for packet detection
preambleLen = 100; % ZC preamble length in complex symbol
u = 25; n = (0:preambleLen-1).';
zc_preamble = exp(-1j*pi*u*n.*(n+1)/preambleLen);  
 
% Apply RRC for pulse shaping and to limit the bandwidth
txfilter = comm.RaisedCosineTransmitFilter(...
    OutputSamplesPerSymbol  = 8, ...
    RolloffFactor           = 0.25 ...
    );
txdatasymbol = [zc_preamble;txmodulated]; % data packet starts with preamble
txwave = txfilter([txdatasymbol;zeros(10,1)]); % Flush with zero
normalizedtxwave = txwave /sqrt(mean(abs(txwave).^2));
numRepeats = 10;                                  
txBuf = repmat(normalizedtxwave, numRepeats, 1); % fill the buffer with the same repition of the signal to avoid underrun the buffer

% ========= Prepare Receiver side operations =========
% Build the reference preamble for packet detection
txfilter = comm.RaisedCosineTransmitFilter(...
    OutputSamplesPerSymbol  = 8, ...
    RolloffFactor           = 0.25 ...
    );
ref_preamble = txfilter([zc_preamble;zeros(10,1)]);
ref_preamble = ref_preamble / norm(ref_preamble);

% Equalize the power of receiveing signal to achieve a constant signal level
agc = comm.AGC(...
    AdaptationStepSize   = 1e-3,...
    MaxPowerGain         = 20 ...
    );

% apply matched filtering before sampling
rxfilter = comm.RaisedCosineReceiveFilter(...
    InputSamplesPerSymbol   =8,...
    DecimationFactor        =1, ...
    RolloffFactor           = 0.25 ...
    );

% Compensates for the frequency offset (In case two modules are connected with MIMO cable, it can be removed)
cfc = comm.CoarseFrequencyCompensator(...
    Modulation          = "QAM",...
    SampleRate          = fs,...
    FrequencyResolution = 1 ...
    );

% 
symSync = comm.SymbolSynchronizer(...
    Modulation              = "PAM/PSK/QAM", ...
    TimingErrorDetector     = "Gardner (non-data-aided)",...
    SamplesPerSymbol        = 8,...
    NormalizedLoopBandwidth = 0.001);


% Compensate for frequency and phase offsets in signals that use single-carrier modulation schemes:
carSync = comm.CarrierSynchronizer(...
    Modulation              = "QAM",...
    SamplesPerSymbol        = 8,...
    DampingFactor           = 1,...
    NormalizedLoopBandwidth = 0.001);

% ========= Start transmission and receiption =========
disp('Starting single-host TX (ch1) and RX (ch2)...');
tStart = tic;

while toc(tStart) < Tsec
    
    TX(txBuf); % feeding the transmitter

    [rxFrame, valid] = RX(); % Start receiving, rxFrame is sampled I/Qs
    % Keep receiving until a packet is really captured
    if ~valid || isempty(rxFrame)
        continue;
    end

    % Packet is captured, apply the receiving chain of operations
    y = agc(rxFrame);   % Operation1 : Equilizer
    y = rxfilter(y);    % matched filter the receiving signal
    y = cfc(y);         % coarse CFO 

    % find the begining of the transmitted signal
    [corr,lags] = xcorr(y,ref_preamble);
    corr = abs(corr);
    normFactor = sqrt( sum(abs(y).^2) * sum(abs(ref_preamble).^2) );
    corr = corr/normFactor;
    %Find the peaks of the cross-correlation
    [pks, locs] = findpeaks(corr, 'MinPeakHeight', max(corr)*0.5);
    % Select the highest peak
    [peakValue, max_idx] = max(pks);
    if peakValue > 1e-2 % packet detected
        disp("Preamble was decected. Processing....")
        %startSamplingIndex = peakIndex + 1;

    else
        disp("Frame dropped.")
    end
end  

%% -------- Cleanup --------
release(TX);
release(RX);