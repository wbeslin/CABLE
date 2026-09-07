%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "computeIPI"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       none
%
%   Description:
%       Computes the IPI of a sperm whale click and assesses its precision.
%       A click's IPI is currently derived from two methods:
%       autocorrelation (absolute peak), and cepstrum. Both methods are
%       implemented as described in Goold (1996).
%
%   Input:
%       x [n-by-1 double]:
%           Vector of waveform amplitudes
%       Fs [1-by-1 double]"
%           Sampling rate, in Hertz
%       clickRange [2-by-n double]:
%           Start and end samples of the click
%       IPIRange [1-by-2 double]:
%           The minimum and maximum IPI limits, in milliseconds
%       maxIPIDeviation [1-by-1 double]:
%           The maximum acceptable difference between the IPI values of a
%           click that were computed using different methods (i.e. 
%           autocorrelation and cepstrum). This parameter is what controls 
%           IPI precision.
%       doIPIMethod [1-by-1 struct]:
%           Struct with field names corresponding to each IPI computation
%           method (i.e. "Autocorrelation" and "Cepstrum"). Each field
%           contains a logical that dictates if that method should be used
%           or not.
%       useChiSquared [1-by-1 struct]:
%           Struct with field names corresponding to each IPI computation
%           method (i.e. "Autocorrelation" and "Cepstrum"). Each field
%           contains a logical that dictates if Chi-Squared type windows
%           should be applied to each click before IPI calculation, in 
%           order to amplify the signal of decaying pulses (Goold, 1996).
%       nfft [1-by-1 double]:
%           Number of samples to use in FFT. Works best as a power of 2.
%       nTukeyFalloff [1-by-1 double]:
%           Number of samples in the falloff regions of each Tukey window
%           applied before FFT. This is only used if 
%           "useChiSquared.Cepstrum" = false. If a Chi-Squared window is
%           not used, a Tukey window is applied instead before computing 
%           the cepstrum IPI.
%       freqBand [1-by-2 double]:
%           Frequency passband being examined. This should really be equal 
%           to the passband of the noise filter. It is used to re-filter 
%           the spectrum (using a Tukey window with a falloff of 1 kHz) to 
%           attenuate the effects of rippling due to the Gibbs phenomenon. 
%           Unwanted rippling can seriously confound the cepstrum IPI.
%
%   Output:
%       IPIFinal [1-by-1 double]:
%           The click's singular IPI measure. An average of autocorrelation
%           and cepstrum IPIs.
%       isPrecise [1-by-1 logical]:
%           Specifies if the IPI measure is precise; that is, if both 
%           autocorrelation and cepstrum IPI values agree within a certain 
%           tolerance.
%
%   Acknowledgements:
%       Parts of this code, notably the local functions 
%       "IPI_Autocorrelation" and "IPI_Cepstrum", were built upon code 
%       written by Luke Rendell and Tyler Schulz.
%
%   References:
%       Goold, J. C. (1996). “Signal processing techniques for acoustic
%           measurement of sperm whale body lengths,” J. Acoust. Soc. Am. 
%           100, 3431–3441.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [IPIFinal,isPrecise] = computeIPI(x,Fs,clickRange,...
    IPIRange,maxIPIDeviation,doIPIMethod,useChiSquared,nfft,nTukeyFalloff,freqBand)

    % INITIALIZE VARIABLES
    if any([useChiSquared.Autocorrelation,useChiSquared.Cepstrum])
        chi_k = 4;
        chi_xMax = 10;
        xChi = CABLE.Routine.applyWindow_ChiSquared(x(clickRange(1):clickRange(2)),chi_k,chi_xMax);
    end
    IPICell = cell(1,2);
    nClickSamples = diff(clickRange) + 1;
    % END VARIABLE INITIALIZATIONS
    
    % Make sure click is longer than the minimum IPI. If it's not, abort.
    % Click detector is designed to prevent this, so it shouldn't happen.
    if nClickSamples < IPIRange(1)*(Fs/1000)
        IPIFinal = NaN;
        isPrecise = false;
        return
    end
    
    % 1) AUTOCORRELATION IPI
    if doIPIMethod.Autocorrelation
        
        % decide window to use: rectangular or Chi-Squared
        if useChiSquared.Autocorrelation
            xIPI = xChi;
        else
            xIPI = x(clickRange(1):clickRange(2));
        end
        
        % Get autocorrelation IPI
        IPICell{1} = IPI_Autocorrelation(xIPI,Fs,IPIRange);
    end
    
    % 2) CEPSTRUM IPI
    if doIPIMethod.Cepstrum
        
        % Decide window to use: Tukey or Chi-Squared
        if useChiSquared.Cepstrum
            xIPI = xChi;
        else
            xIPI = CABLE.Routine.applyWindow_Tukey(x,clickRange,nTukeyFalloff);
        end
        
        % Get cepstrum IPI
        IPICell{2} = IPI_Cepstrum(xIPI,Fs,clickRange,IPIRange,nfft,freqBand);
    end
    
    % 3) FINAL IPI
    IPIVec = [IPICell{:}];
    IPIFinal = median(IPIVec);
    
    % 4) PRECISION ASSESSMENT
    isPrecise = assessIPIPrecision(IPIFinal,IPIVec,maxIPIDeviation);
end

%% IPI_Autocorrelation ----------------------------------------------------
function IPI = IPI_Autocorrelation(xIPI,Fs,IPIRange)
% Computes a sperm whale click's IPI based on autocorrelation. The IPI in 
% this case is measured as the absolute peak of the autocorrelation 
% function (Goold, 1996).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % INITIALIZE VARIABLES
    nSamples = numel(xIPI);
    FskHz = Fs/1000;
    lags = (floor(IPIRange(1)*FskHz):floor(IPIRange(2)*FskHz))';
    maxLag = lags(end);
    nLags = length(lags);
    lags_t = lags./FskHz;
    % END VARIABLE INITIALIZATION
    
    % If click is shorter than the upper IPI limit), zero-pad the tail. 
    % Otherwise correlation will "overshoot" and cause problems.
    if nSamples <= maxLag
        xIPI(nSamples+1:maxLag+1) = 0;
        nCorrSamples = numel(xIPI);
    else
        nCorrSamples = nSamples;
    end
    
    % Do autocorrelation
    corrFunc = zeros(nLags,1);
    for ii = 1:nLags
        dt = lags(ii);
        xIPIDelta = [zeros(dt,1);xIPI(1:(nCorrSamples-dt))];
        corrFunc(ii) = CABLE.Routine.correlation(xIPI,xIPIDelta);
    end
    
    % Get absolute peak correlation (i.e. the IPI)
    [~,iPeakCorr] = max(abs(corrFunc));
    IPI = lags_t(iPeakCorr);
end

%% IPI_Cepstrum -----------------------------------------------------------
function IPI = IPI_Cepstrum(xIPI,Fs,clickRange,IPIRange,nfft,freqBand)
% Computes a sperm whale click's IPI based on the cepstrum. The IPI in this 
% case is taken to be the peak quefrency of the power cepstrum (Goold, 
% 1996).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Get power spectrum (1st FFT)
    [f,XPow] = CABLE.Routine.computeSpectrum(xIPI,nfft,Fs);
    XPowLog = log10(XPow);
    clear XPow
    
    % Filter the spectrum using a Tukey window.
    % This is necessary, because there are actually small unwanted ripples
    % in the spectrum (due to Gibbs phenomenon - prior windowing helps but 
    % is not perfect, and logging makes the effect more apparent). These
    % ripples create a significant peak in the cepstrum, which really 
    % messes up IPI estimation. Applying a Tukey window directly to the 
    % spectrum greatly reduces the problem.
    tukeyFalloff_Freq = 1000; % 1 kHz falloff
    df = unique(diff(f));
    tukeyFalloff_n = round(tukeyFalloff_Freq/df);
    iFreqLeftCutoff = find(f >= freqBand(1),1,'first');
    iFreqRightCutoff = find(f <= freqBand(2),1,'last');
    XPowLogWin = CABLE.Routine.applyWindow_Tukey(XPowLog,[iFreqLeftCutoff,iFreqRightCutoff],tukeyFalloff_n);
    
    % Get power (or "woper"?) cepstrum (2nd FFT)
    quefFsms = nfft/(Fs/1000); % "sampling quefrency"
    [quefs,cepPow] = CABLE.Routine.computeSpectrum(XPowLogWin,nfft,quefFsms);
    
    % get cepstrum peak within IPI/click range
    clickDuration = (diff(clickRange) + 1)/(Fs/1000);
    minIPI = IPIRange(1);
    maxIPI = min([IPIRange(2),clickDuration]);
    iMinIPI = find(quefs >= minIPI,1,'first');
    iMaxIPI = find(quefs <= maxIPI,1,'last');
    [~,iiIPI] = max(cepPow(iMinIPI:iMaxIPI));
    IPI = quefs(iiIPI + iMinIPI - 1);
end

%% assessIPIPrecision -----------------------------------------------------
function isPrecise = assessIPIPrecision(IPIFinal,IPIVec,maxIPIDeviation)
% Determines if a click's IPI estimates are precise or not. By "precise",
% I mean that they all agree on the same value, within tolerance. This is
% assessed based on maximum absolute deviation.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if numel(IPIVec) > 1
        deviations = abs(IPIVec - IPIFinal);
        isPrecise = max(deviations) <= maxIPIDeviation;
    else
        isPrecise = true;
    end
end
    
