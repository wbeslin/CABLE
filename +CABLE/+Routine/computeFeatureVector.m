%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "computeFeatureVector"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       Signal Processing Toolbox
%
%   Description:
%       Obtains the values of features for one click, which will be used 
%       later to classify it.
%
%   Input:
%       x [n-by-1 double]:
%           Vector of waveform amplitudes
%       xEnv [n-by-1 double]:
%           Vector of waveform envelope amplitudes
%       Fs [1-by-1 double]:
%           Sampling rate, in Hertz
%       clickRange [2-by-n double]:
%           Start and end samples of the click
%       pageNoise [n-by-1 double]:
%           Vector of noise power estimates computed during click detection
%       f [n-by-1 double]:
%           Vector of frequencies for power spectrum, up to 1/(Fs/2)
%       XPow [n-by-1 double]:
%           Vector of spectral power amplitudes for every corresponding
%           frequency in "f"
%       pulseRanges [2-by-n double]:
%           Matrix of start and end samples for each pulse
%       expFit [1-by-1 struct]:
%           Struct with fields "a", "b", and "r2". These contain the 
%           coefficients and r-squared goodness-of-fit for an exponential
%           curve fit to the amplitudes of the pulses in the click. 
%
%   Output:
%       features [1-by-n double]:
%           Vector of feature values for a click
%
%   References:
%       Au, W. W. L. (1993). The Sonar of Dolphins (Springer, New York).
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function features = computeFeatureVector(x,xEnv,Fs,clickRange,pageNoise,f,XPow,pulseRanges,expFit)

    % INITIALIZE VARIABLES
    %%% NOTE: The classifier expects each feature to be in a certain order, 
    %%% so the order in which features are computed is important!
    featFuncs = {...
        @getClickDuration,...
        @getPeakSNR,...
        @getPeakFrequency,...
        @getCentroidFrequency,...
        @getNeg3dBBandwidth,...
        @getNeg10dBBandwidth,...
        @getRMSBandwidth,...
        @getPulseCount,...
        @getPulseDurationMean,...
        @getPulseDurationVariance,...
        @getPulseZCRVariance,...
        @getPulseBestCorrelation,...
        @getTallestPulseGaussFitR2,...
        @getExpFitA,...
        @getExpFitB,...
        @getExpFitR2};
    nfeatures = numel(featFuncs);
    features = zeros(1,nfeatures);
    % END VARIABLE INITIALIZATION
    
    % loop through and compute each feature
    for ii = 1:nfeatures
        features(ii) = feval(featFuncs{ii});
    end
    
    % NESTED FUNCTIONS
    %% getClickDuration ...................................................
    function cd = getClickDuration()
    % Extracts click durations in milliseconds.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        cd = ((diff(clickRange) + 1)/Fs)*1000;
    end

    %% getPeakSNR .........................................................
    function psnr = getPeakSNR()
    % Extracts SNR at the peak sample (as power ratio in dB)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        clickSamples = clickRange(1):clickRange(2);
        clickEnv = xEnv(clickSamples);
        clickPowNoise = pageNoise(clickSamples);
        [clickEnvPeak,ipeak] = max(clickEnv);
        clickPowSignalPeak = clickEnvPeak^2;
        clickPowNoisePeak = clickPowNoise(ipeak);
        psnr = 20*log10(clickPowSignalPeak./clickPowNoisePeak);   
    end

    %% getPeakFrequency ...................................................
    function fPeak = getPeakFrequency()
    % Extracts peak frequency of click spectra.
    % Peak frequency is the frequency at which the power spectrum is at
    % maximum.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        [~,ifPeak] = max(XPow);
        fPeak = f(ifPeak);
    end

    %% getCentroidFrequency ...............................................
    function f0 = getCentroidFrequency()
    % Extracts centroid frequency of click spectra.
    % According to Au (1993), the centroid frequency divides the power
    % spectrum into two halves of equal energy.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        f0 = centroidFrequency(f,XPow);
    end

    %% getNeg3dBBandwidth .................................................
    function bw_n3dB = getNeg3dBBandwidth()
    % Extracts -3 dB bandwidth of click power spectrum.
    % -3 dB bandwidth is the frequency interval between the points about 
    % the peak frequency where spectral power attenuates by 3 dB relative 
    % to the peak. 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        bw_n3dB = dBBandwidth(f,XPow,-3);
    end

    %% getNeg10dBBandwidth .................................................
    function bw_n10dB = getNeg10dBBandwidth()
    % Extracts -10 dB bandwidth of click power spectrum.
    % -10 dB bandwidth is the frequency interval between the points about 
    % the peak frequency where spectral power attenuates by 10 dB relative 
    % to the peak. 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        bw_n10dB = dBBandwidth(f,XPow,-10);
    end

    %% getRMSBandwidth ....................................................
    function bw_rms = getRMSBandwidth()
    % Extracts RMS bandwidth of click spectra.
    % This is a bandwidth measured about the centroid frequency. It is 
    % supposedly a good measure for broadband clicks (Au, 1993).
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        % get centroid frequency
        f0 = centroidFrequency(f,XPow);
        
        % get frequency interval
        df = unique(diff(f));
        
        % bandwidth
        fsq = sum(((f.^2).*XPow)*df)/sum(XPow*df);
        bw_rms = sqrt(fsq - f0^2);
    end

    %% getPulseCount ......................................................
    function np = getPulseCount()
    % Extracts number of pulses within a click.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        np = pulseCount(pulseRanges);
    end

    %% getPulseDurationMean ................................................
    function pdm = getPulseDurationMean()
    % Extracts mean pulse duration in seconds.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        pdm = mean(pulseDurations(pulseRanges,Fs));
    end

    %% getPulseDurationVariance ...........................................
    function pdv = getPulseDurationVariance()
    % Extracts mean pulse duration in seconds.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        pdv = var(pulseDurations(pulseRanges,Fs));
    end

    %% getPulseZCRVariance ................................................
    function pzcrv = getPulseZCRVariance()
    % Extracts variance of zero-crossing rate among pulses
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        % get zero crossing rate
        nPulses = pulseCount(pulseRanges);
        zcrs = zeros(1,nPulses);
        for jj = 1:nPulses
            % get pulse samples
            rangejj = pulseRanges(:,jj);
            xjj = x(rangejj(1):rangejj(2));
            
            % zero crossings
            nzcejj = sum((xjj(1:end-1).*xjj(2:end)) < 0); % definition of zero crossing events
            zcrjj = nzcejj./(numel(xjj)-1);
            zcrs(jj) = zcrjj;
        end
        
        % variance
        pzcrv = var(zcrs);
        
    end

    %% getPulseBestCorrelation ............................................
    function pbc = getPulseBestCorrelation()
    % Returns the value of the best cross-correlation between the tallest 
    % pulse and other pulses. Pulses are scaled to 1, peak-aligned, and 
    % trimmed to have the same length.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        % find tallest pulse
        [iTallest,iPeakTallest] = tallestPulse(pulseRanges,xEnv);
        
        % establish pulses to loop through
        nPulses = pulseCount(pulseRanges);
        loopPulses = 1:nPulses;
        loopPulses(iTallest) = [];
        
        % loop through each non-tallest pulse
        peakCorr = zeros(1,numel(loopPulses));
        for jj = loopPulses
            % get length of pulse jj. Waveform segment to be cross-
            % correlated spans twice this range, centered about the peak of 
            % the tallest pulse. Use a zero-pad safety net in case there 
            % isn't enough waveform to sample (rare).
            samplesjj = pulseRanges(1,jj):pulseRanges(2,jj);
            xjj = x(samplesjj);
            nsamplesjj = numel(xjj);
            xcorrSamplesjj = iPeakTallest-nsamplesjj:iPeakTallest+nsamplesjj;
            validSamplesjj = (xcorrSamplesjj > 0) & (xcorrSamplesjj <= numel(x));
            xTallestCorrjj = zeros(numel(xcorrSamplesjj),1);
            xTallestCorrjj(validSamplesjj) = x(xcorrSamplesjj(validSamplesjj));
            xTallestCorrjj = xTallestCorrjj./max(abs(xTallestCorrjj));
            x_xcorrjj = xjj./max(abs(xjj));
            
            % initialize offset and do cross correlation
            xcorrvecjj = zeros(nsamplesjj,1);
            for kk = 1:nsamplesjj
                corrOffset = nsamplesjj-kk;
                xTallestCorrkk = xTallestCorrjj((1:nsamplesjj)+corrOffset);
                xcorrvecjj(kk) = CABLE.Routine.correlation(xTallestCorrkk,x_xcorrjj);
            end
            % save the peak correlation value
            peakCorr(jj) = max(abs(xcorrvecjj));
        end
        
        % get best peak correlation
        pbc = max(peakCorr);
    end

    %% getTallestPulseGaussFitR2 ..........................................
    function tpgfr2 = getTallestPulseGaussFitR2()
    % Returns the R^2 goodness of fit for a Gaussian curve fitted to the 
    % tallest pulse.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        % find tallest pulse and get its envelope
        [iTallest,iPeakTallest] = tallestPulse(pulseRanges,xEnv);
        iiPeakTallest = iPeakTallest - pulseRanges(1,iTallest) + 1;
        samplesTallest = pulseRanges(1,iTallest):pulseRanges(2,iTallest);
        nsamplesTallest = numel(samplesTallest);
        xEnvTallest = xEnv(samplesTallest);
        
        % Gaussian fitting
        gaussFit_y = xEnvTallest./max(xEnvTallest);
        gaussFit_x = (1:nsamplesTallest)';
        coeffLowerBounds = [0,1,0];
        coeffUpperBounds = [2,nsamplesTallest,nsamplesTallest*2];
        coeffStart = [1,iiPeakTallest,nsamplesTallest/2];
        [fo,gaussGOF] = fit(gaussFit_x,gaussFit_y,'gauss1',...
            'Lower',coeffLowerBounds,...
            'Upper',coeffUpperBounds,...
            'StartPoint',coeffStart);
        tpgfr2 = gaussGOF.rsquare;
        
        % DEBUG
        %{
        dodebug = false;
        if dodebug
            fo;
            boxP = [0,xEnv(iPeakTallest)*[1,1],0];
            boxC = [0,max(xEnv(clickRange(1):clickRange(2)))*[1,1],0];
            iTall = (pulseRanges(1,iTallest):pulseRanges(2,iTallest))';
            figure
            plot(xEnv)
            hold on
            plot([clickRange(1)*[1,1],clickRange(2)*[1,1]],boxC,'LineWidth',3)
            plot([pulseRanges(1,iTallest)*[1,1],pulseRanges(2,iTallest)*[1,1]],boxP,'--','LineWidth',3)
            plot(iTall,xEnv(iTall),'o')
            %a = fo.a1;
            %b = fo.b1;
            %c = fo.c1;
            xf = linspace(1,numel(iTall),1000)';
            yf = fo(xf);
            plot(xf + (pulseRanges(1,iTallest) - 1),yf)
            xlim([1,numel(xEnv)])
            title(sprintf('R^2 = %.3g',tpgfr2))
        end
        %}
        % END DEBUG
    end

    %% getExpFitA .........................................................
    function a = getExpFitA()
    % Returns the "a" coefficient from the best exponential fit to pulse
    % peaks
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        a = expFit.a;
    end

    %% getExpFitB .........................................................
    function b = getExpFitB()
    % Returns the "b" coefficient from the best exponential fit to pulse
    % peaks
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        b = expFit.b;
    end

    %% getExpFitR2 .........................................................
    function r2 = getExpFitR2()
    % Returns the R squared goodness of fit for the best exponential fit to 
    % pulse peaks
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        r2 = expFit.r2;
    end
end

% LOCAL UTILITY FUNCTIONS
%% centroidFrequency ------------------------------------------------------
function f0 = centroidFrequency(f,XPow)
% Returns the centroid frequency of a power spectrum, using the equation in 
% Au (1993).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % get frequency interval
    df = unique(diff(f));

    % centroid frequency
    f0 = sum((f.*XPow)*df)/sum(XPow*df);
end

%% dBBandwidth ------------------------------------------------------------
function bw_dB = dBBandwidth(f,XPow,dBVal)
% Returns the bandwidth of a power spectrum at some dB value relative to
% the peak frequency.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % get peak frequency.
    % In the rare case that there are multiple peaks with the same value, 
    % return NaN. 
    [~,ifPeak] = max(XPow);
    if numel(ifPeak) > 1
        bw_dB = NaN;
        return
    end
    fPeak = f(ifPeak);
    
    % determine reference amplitude at dB re fpeak, and use it to determine
    % the bases of XPow at peak frequency
    XPowIntercept = XPow(ifPeak)*10^(dBVal/20);
    bwRange = CABLE.Routine.peakExtents(f,XPow,fPeak,XPowIntercept,true);
    bw_dB = diff(bwRange);
end

%% pulseCount -------------------------------------------------------------
function n = pulseCount(pulseRanges)
% Returns number of pulses. Assumes that columns in "pulseRanges" are
% pulses, and rows are starts/ends/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    n = size(pulseRanges,2);
end

%% pulseDurations ---------------------------------------------------------
function pd = pulseDurations(pulseRanges,Fs)
% Returns a vector of pulse durations in milliseconds.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    pd = ((diff(pulseRanges,1) + 1)/Fs)*1000;
end

%% tallestPulse -----------------------------------------------------------
function [iTallest,iPeakTallest] = tallestPulse(pulseRanges,xEnv)
% Returns the index of the tallest pulse, and the absolute sample index of 
% its peak amplitude.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    nPulses = pulseCount(pulseRanges);
    xPulsePeaks = zeros(1,nPulses);
    iPulsePeaks = zeros(1,nPulses);
    for ii = 1:nPulses
        pulseSamplesii = pulseRanges(1,ii):pulseRanges(2,ii);
        [xPulsePeakii,iiPulsePeakii] = max(xEnv(pulseSamplesii));
        iPulsePeakii = pulseSamplesii(iiPulsePeakii);
        xPulsePeaks(ii) = xPulsePeakii;
        iPulsePeaks(ii) = iPulsePeakii;
    end
    [~,iTallest] = max(xPulsePeaks); 
    iPeakTallest = iPulsePeaks(iTallest);
end