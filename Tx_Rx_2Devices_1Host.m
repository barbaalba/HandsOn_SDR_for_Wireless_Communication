clc;clear;close all;
% ----------- Module SETTINGS -----------
fc       = 2.45e9;      % Carrier frequency
txgain     = 20;         % RF  gain
rxgain     = 20;         % RF gain
decim    = 512;         % decimation (100e6/512 ≈ 195.3125 kS/s)
Tsec     = 12;          % capture duration (seconds)
mcr = 100e6;            %  master clock rate is the analog to digital (A/D) and digital to analog (D/A) clock rate
fs = 1e6;               % Effective base band sampling rate for up and down sampling
sps = 8;
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
    OutputSamplesPerSymbol  = sps, ...
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
    OutputSamplesPerSymbol  = sps, ...
    RolloffFactor           = 0.25 ...
    );
ref_preamble = txfilter([zc_preamble;zeros(10,1)]);
ref_preamble = ref_preamble / norm(ref_preamble);

% Equalize the power of receiveing signal to achieve a constant signal level
agc = comm.AGC(...
    AdaptationStepSize   = 1e-3,...
    MaxPowerGain         = 20 ...
    );

% apply matched filtering before sampling for ISI reduction or SNR increase
rxfilter = comm.RaisedCosineReceiveFilter(...
    InputSamplesPerSymbol   = sps,...
    DecimationFactor        = 1, ...
    RolloffFactor           = 0.25 ...
    );

% Compensates for the frequency offset (In case two modules are connected with MIMO cable, it can be removed)
cfc = comm.CoarseFrequencyCompensator(...
    Modulation          = "QAM",...
    SampleRate          = fs,...
    FrequencyResolution = 1 ...
    );

% It finds the optimal sampling instance and then resamples it down to 1
% sample per symbol instead of sps (rate reduction or downsampling)
symSync = comm.SymbolSynchronizer(...
    Modulation              = "PAM/PSK/QAM", ...
    TimingErrorDetector     = "Gardner (non-data-aided)",...
    SamplesPerSymbol        = sps,...
    NormalizedLoopBandwidth = 0.001);


% Compensate for frequency and phase offsets in signals that use single-carrier modulation schemes:
carSync = comm.CarrierSynchronizer(...
    Modulation              = "QAM",...
    SamplesPerSymbol        = 1,...
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
    peakIndex = lags(locs(max_idx));
    if peakValue > 1e-2 % packet detected
        disp("Preamble was decected. Processing....")
        
        % Extract the interesting portion of the frame
        startSamplingIndex = peakIndex + 1;
        winLength = sps * symbolnum; % Length of the window to consider for processing
        endSamplingIndex = min(length(y), startSamplingIndex + winLength  - 1);
        y = y(startSamplingIndex:endSamplingIndex);

        % Find the precise sampling location and the downsample to symbol
        % rate
        if length(y) ~= sps * symbolnum
            disp("The entire data was not captured! It is dropped...");
            continue;
           
        else
            ysym = symSync(y);

            % Correct for residual carrier and phase error
            ysym = carSync(ysym);

            % Demodulation
            demodulatedData = qamdemod(ysym, M);

            disp(["length of demodulated data: ", size(demodulatedData)]);

            errorRate = sum(demodulatedData ~= txsymbols)/length(txsymbols)*100;
            disp(["Symbol error rate is: ", errorRate]);
           
        end
    else
        disp("Frame dropped.")
    end
end  

%% -------- Cleanup --------
release(TX);
release(RX);