%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "applyWindow_Tukey"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       none
%
%   Description:
%       Returns a Tukey-windowed section of an input data vector.
%
%   Input:
%       x [n-by-1 OR 1-by-n double]: 
%           Data vector to window
%       flatRange [1-by-2 double]:
%           The start and end samples of the range in "x" that should be 
%           kept unaltered (i.e. the flat section of Tukey window)
%       nFalloff [1-by-1 double]:
%           Length of each wing in samples (wings are the non-flat sections 
%           of the Tukey window).
%
%   Output:
%       xWin [n-by-1 OR 1-by-n double]:
%           Tukey-windowed section of "x" (zeros are NOT included)
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function xWin = applyWindow_Tukey(x,flatRange,nFalloff)

    % get input orientation
    if iscolumn(x)
        vecsize = @(n) [n,1]; 
        catfun = @vertcat;
    elseif isrow(x)
        vecsize = @(n) [1,n]; 
        catfun = @horzcat;
    else
        error('Expected "x" to be a vector')
    end
    
    % process flat region
    xFlat = x(flatRange(1):flatRange(2));
    
    % check size of Tukey wings. If they are 0, then this is just a
    % rectangular window: return flat region.
    if nFalloff == 0
        xWin = xFlat;
        return
    end
    
    % initialize Tukey wing cosine samples
    cosSamples = linspace(0,pi,nFalloff);
    cosSamples = reshape(cosSamples,vecsize(nFalloff));

    % Process left wing
    %%% isolate data. If there's not enough, add zeros.
    iMin = 1;
    iLeftWing = flatRange(1) - (nFalloff:-1:1);
    if iLeftWing(1) < iMin
        nLeftMissing = sum(iLeftWing < iMin);
        xLeft = catfun(zeros(vecsize(nLeftMissing)),x(iLeftWing(iLeftWing >= iMin)));
    else
        xLeft = x(iLeftWing);
    end
    %%% apply left wing window (rising half-cosine)
    winLeft = 0.5*(cos(cosSamples+pi) + 1);
    xLeft = xLeft.*winLeft;
    
    % Process right wing
    %%% isolate data. If there's not enough, add zeros.
    iMax = numel(x);
    iRightWing = (1:nFalloff) + flatRange(2);
    if iRightWing(end) > iMax
        nRightMissing = sum(iRightWing > iMax);
        xRight = catfun(x(iRightWing(iRightWing <= iMax)),zeros(vecsize(nRightMissing)));
    else
        xRight = x(iRightWing);
    end
    %%% apply right wing window (falling half -cosine)
    winRight = 0.5*(cos(cosSamples) + 1);
    xRight = xRight.*winRight;
    
    % piece everything together
    xWin = catfun(xLeft,xFlat,xRight);
end