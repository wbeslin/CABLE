%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "extractFeatures"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       none
%
%   Description:
%       Computes features from a click to be used for classification.
%
%   Input:
%       x [n-by-1 double]:
%           Vector of waveform amplitudes
%       xEnv [n-by-1 double]:
%           Vector of waveform envelope amplitudes
%       Fs [1-by-1 double]:
%           Sampling rate in Hertz
%       clickRange [2-by-1 double]:
%           Start and end samples of the click
%       pageNoise [n-by-1 double]:
%           Vector of noise power estimates computed during click detection
%       minPulseDuration [1-by-1 double]:
%           Minimum expected duration of individual pulses within sperm
%           whale clicks, in milliseconds
%       maxPulseDuration [1-by-1 double]:
%           Maximum expected duration of individual pulses within sperm
%           whale clicks, in milliseconds
%       minPulseSep [1-by-1 double]:
%           Minimum expected separation between pulses, in milliseconds
%       smoothBandwidths [1-by-n double]:
%           Vector of bandwidths to use for waveform envelope smoothing
%           during pulse detection, from narrowest to widest. Units are in 
%           milliseconds.
%       nSmoothRuns [1-by-1 double]:
%           Number of times to run the envelope smoothing filter in 
%           succession during pulse detection
%       peakBaseHeightProp [1-by-1 double]:
%           Proportion of the peak-to-base height of a pulse to use as the 
%           reference point for estimating pulse duration
%       promThreshProp [1-by-1 double]:
%           Proportion of the difference between the prominences of the
%           most and least prominent peaks in a smoothed envelope. This is
%           used to determine the minimum prominence that a peak may have
%           to indicate the presence of a pulse.
%       minPromThresh [1-by-1 double]:
%           Threshold determining the minimum prominence that a peak may
%           have to be considered as a signal
%       nfft [1-by-1 double]:
%           Number of samples to use in FFT
%       nTukeyFalloff [1-by-1 double]:
%           Number of samples in the falloff regions of each Tukey window
%           used before FFT
%
%   Ouptut:
%       features [1-by-n double]:
%           Vector of feature values for a click
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function features = extractFeatures(x,xEnv,Fs,clickRange,pageNoise,...
    minPulseDuration,maxPulseDuration,minPulseSep,smoothBandwidths,nSmoothRuns,peakBaseHeightProp,promThreshProp,minPromThresh,...
    nfft,nTukeyFalloff)

    % INITIALIZE VARIABLES
    nMinPulses = 2;
    nFeatures = 16;
    % END VARIABLE INITIALIZATIONS
    
    % 1) detect pulses
    pulseRanges = CABLE.Routine.detectPulses(xEnv,Fs,clickRange,...
        minPulseDuration,maxPulseDuration,minPulseSep,smoothBandwidths,nSmoothRuns,peakBaseHeightProp,promThreshProp,minPromThresh);
    % check number of pulses. If there are too few, abort feature 
    % extraction immediately (clicks need at least 2 pulses to compute all
    % features. Any NaN features will result in a classifier score of NaN).
    npulses = size(pulseRanges,2);
    if npulses < nMinPulses
        features = NaN(1,nFeatures);
        return
    end
    
    % 2) compute spectrum
    % apply Tukey window first
    xfft = CABLE.Routine.applyWindow_Tukey(x,clickRange,nTukeyFalloff);
    [f,XPow] = CABLE.Routine.computeSpectrum(xfft,nfft,Fs);
    
    % 3) fit exponential curve
    expFit = CABLE.Routine.fitExp(xEnv,pulseRanges);
    
    % 4) use collected information to compile feature vector
    features = CABLE.Routine.computeFeatureVector(x,xEnv,Fs,clickRange,pageNoise,f,XPow,pulseRanges,expFit);
end