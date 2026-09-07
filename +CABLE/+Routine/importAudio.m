%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "importAudio"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       Signal Processing Toolbox
%
%   Description:
%       This function reads in samples from a single channel of an audio 
%       file, and corrects them for DC bias. If the original signal was not
%       sampled at the desired rate, it is automatically resampled.
%       Resampling is done using the Signal Processing Toolbox's "resample"
%       function, which uses an antialiasing FIR filter with a Kaiser
%       window (beta = 5). Filter order is 2*n*max(p,q), where p/q is the
%       (reduced) resampling ratio. "n" is hard-coded to 25 here, so for
%       example, downsampling from 96 kHz to 48 kHz will create a filter
%       with order 100.
%
%   Input:
%       filePath [1-by-n char]:
%           String specifying the path to an audio file
%       sampleRange [1-by-2 double]:
%           The range of samples to extract from the audio file
%       channelIndex [1-by-1 double]:
%           Number of the audio channel to use
%       Fs [1-by-1 double]:
%           Desired sampling rate, in Hertz
%
%   Output:
%       x [n-by-1 double]:
%           Vector of centralized audio amplitudes
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function x = importAudio(filePath,sampleRange,channelIndex,Fs)

    % 1) read file
    [x,FsRaw] = audioread(filePath,sampleRange);
    
    % 2) isolate wanted channel
    x = x(:,channelIndex);
    
    % 3) remove DC shift
    x = x - mean(x);
    
    % 4) resample if needed
    if FsRaw ~= Fs
        n = 25;
        [p,q] = rat(Fs/FsRaw);
        x = resample(x,p,q,n);
    end
end