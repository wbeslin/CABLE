%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "computeSpectrum"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       Signal Processing Toolbox
%
%   Description:
%       Returns the power spectrum of a time series data vector and its 
%       corresponding frequencies. This function does not perform
%       windowing: the data vector is assumed to have been already windowed
%       as needed. The number of samples used in FFT must be at least as
%       large as the number of samples in the vector, and it is encouraged
%       to be a power of two. If FFT uses more samples than there are
%       available, then the data vector is zero-padded with trailing zeros 
%       (via MATLAB's "fft").
%
%   Input:
%       xfft [n-by-1 OR 1-by-n double]:
%           Time series vector on which to apply FFT
%       nfft [1-by-1 double]:
%           Number of samples to use in FFT
%       Fs [1-by-1 double]:
%           Sampling rate, in Hertz.
%
%   Output:
%       f [n-by-1 OR 1-by-n double]:
%           Vector of frequencies, up to 1/(Fs/2). Has the same orientation
%           (row/column) as "xfft".
%       XPow [n-by-1 OR 1-by-n double]:
%           Vector of spectral power amplitudes for every corresponding
%           frequency in "f".
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [f,XPow] = computeSpectrum(xfft,nfft,Fs)
 
    % validate input
    assert(isvector(xfft),'"xfft" must be a vector')
    assert(nfft >= numel(xfft),'Not enough FFT samples')

    % establish desired indices (i.e. first half of spectrum)
    iUnaliased = 1:(nfft/2);

    % do fft and get power
    X = fft(xfft,nfft); % MATLAB's fft applies zero-padding if nfft > numel(xfft)
    X = X(iUnaliased);
    XPow = abs(X).^2;
    
    % get frequency vector
    f = ((1:nfft)-1)/nfft*Fs; % 1st frequency is 0. This calculation is robust to choice of NFFT.
    f = f(iUnaliased);
    f = reshape(f,size(XPow));
end