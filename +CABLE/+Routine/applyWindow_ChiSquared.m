%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "applyWindow_ChiSquared"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies: 
%       none
%
%   Description:
%       Returns an input data vector windowed using a chi-squared function. 
%       This is a method proposed by Goold (1996) to amplify the decaying 
%       pulses of a sperm whale click prior to IPI calculation.
%
%   Input:
%       x [n-by-1 OR 1-by-n double]: 
%           Data vector to window
%       k [1-by-1 double]:
%           "k" coefficient of the Chi-squared function
%       nMax [1-by-1 double]:
%           Extent over which to evaluate the Chi-squared function
%
%   Output:
%       xWin [n-by-1 OR 1-by-n double]:
%           Chi-square-windowed transformation of "x"
%
%   References:
%       Goold, J. C. (1996). “Signal processing techniques for acoustic
%           measurement of sperm whale body lengths,” J. Acoust. Soc. Am. 
%           100, 3431–3441.
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function xWin = applyWindow_ChiSquared(x,k,nMax)

    % Create window
    n = linspace(0,nMax,numel(x));
    winVec = (1/(2^(k/2)*gamma(k/2))).*n.^((k/2)-1).*exp(-n/2);
    winVec = fliplr(winVec);
    winVec = winVec.*(1/winVec(1));
    winVec = reshape(winVec,size(x));
    
    % Apply window
    xWin = x.*winVec;
end