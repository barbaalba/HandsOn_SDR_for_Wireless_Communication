function [data,Fs] = usrp_receive(ip,fc,gain,decim,Tsec,ch,mimoflag)
% USRP-2932/2921 (Ethernet) receive

    % ======= Radio configuration (Ethernet) =======
    % N200/N210/USRP2 covers the 29xx family for MATLAB's SDRu API
    rx = comm.SDRuReceiver( ...
        Platform         = 'N200/N210/USRP2', ...
        IPAddress        = ip, ...
        ChannelMapping   = ch, ...
        CenterFrequency  = fc, ...      % pick what you need & your daughterboard supports
        Gain             = gain, ...           % start modest; adjust as needed
        DecimationFactor = decim, ...          % The radio uses the decimation factor when it downconverts the intermediate frequency (IF) signal to a complex baseband signal Fs = 100e6 / 200 = 500 kS/s
        OutputDataType   = 'double');     % double-precision floating point values scaled to the range [–1, 1]
    
    if mimoflag
        rx.EnableMIMOCableSync = 1;
        % --------Time Aligned Start---------
        rx.EnableTimeTrigger = true;
        t0 = getRadioTime(rx);      % current radio time from the synchronized radios
        rx.TriggerTime = t0 + 0.5;  % start 0.5 second in future
    else
        rx.ClockSource = "Internal";    % valid: 'Internal' | 'External' (10 MHz clock signal from an external clock generator) | 'GPSDO' (NOTE: for MIMO, use either 'GPSDO' or 'External)
        rx.PPSSource = "Internal";      % Pulse per second (PPS) valid: 'Internal' | 'External' | 'GPSDO' (NOTE: when in MIMO, use either 'External' or 'GPSDO' )
    end
    % (Optional) short burst capture is often more stable on first try:
    rx.EnableBurstMode   = true;
    rx.NumFramesInBurst  = 200;              % tune as desired
    rx.SamplesPerFrame   = 4000;             % tune as desired

    % ======= Capture N seconds =======

    [data, ~] = capture(rx, Tsec, 'Seconds');

    % ======= Visualize spectrum =======
    Fs = rx.MasterClockRate / rx.DecimationFactor;        % N200/N210/29xx ADC base rate is 100 MHz

    % ======= Cleanup =======
    release(rx);
end