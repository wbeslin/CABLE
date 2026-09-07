%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "peakExtents"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies: 
%       none
%
%   Description:
%       Finds the extents of a peak. Extents are defined as the points
%       along a curve on either side of a peak, or local maximum, where the
%       y-axis variable intersects some reference y-value. This function
%       supports two y-intercept values, allowing the peak extents to be
%       asymmetric. 
%   
%   Input:
%       x [n-by-1 OR 1-by-n double]:
%           Vector representing points along the x-axis
%       y [n-by-1 OR 1-by-n double]: 
%           Vector representing points along the y-axis
%       xPeak [1-by-1 double]:
%           x-axis location of the peak. For the function to work as 
%           expected, y must be a local maximum at xPeak.
%       yIntercept [1-by-1 OR 1-by-2 double]:
%           y-value(s) at which peak extents are to be evaluated. Using 2
%           elements allows the extent limits to be asymmetric (one extent 
%           can be defined at a higher point than the other).
%       interpolate [1-by-1 logical]:
%           Specifies if interpolation should be used or not. If true, the 
%           function uses linear interpolation to determine the point at 
%           which the y-axis variable crosses the yIntercept values exactly
%           (in this case, the output variable "iExtents" is undefined and 
%           returns as NaN). If false, then the extents are the first 
%           points within the x and y vectors where y crosses yIntercept 
%           relative to the peak.
%
%   Output:
%       xExtents [1-by-2 double]:
%           x-axis values of the left and right peak extents
%       iExtents [1-by-2 double]:
%           indices of the left and right peak extents. If interpolation
%           was used, these are NaN.
%       truncated [1-by-2 logical]: 
%           indicates if each extent was limited by the bounds of the data 
%           or not. In other words, if an intercept point cannot be found 
%           for a particular extent (left or right), this value would be 
%           true for that extent.
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [xExtents,iExtents,truncated] = peakExtents(x,y,xPeak,yIntercept,interpolate)

    % process and validate input
    if numel(yIntercept) == 1
        yInterceptLeft = yIntercept;
        yInterceptRight = yIntercept;
    elseif numel(yIntercept) == 2
        yInterceptLeft = yIntercept(1);
        yInterceptRight = yIntercept(2);
    else
        error('input parameter "yIntercept" must have either one or two elements')
    end
    assert(all(size(x) == size(y)) && isvector(x),'x and y must both be vectors of the same size')
    iPeak = find(x == xPeak);
    assert(isscalar(iPeak),'invalid value of "xPeak"')
    
    % left extent
    iLimitLeft = 1;
    noIntercept = true;
    ii = iPeak;
    while noIntercept
        yii = y(ii);
        if yii <= yInterceptLeft
            if (interpolate) && (ii ~= iPeak)
                % interpolate
                iinterp = [ii,ii+1];
                xExtentLeft = interp1(y(iinterp),x(iinterp),yInterceptLeft);
                iExtentLeft = NaN;
            else
                % use vector index
                xExtentLeft = x(ii);
                iExtentLeft = ii;
            end
            truncLeft = false;
            noIntercept = false;
        elseif ii == iLimitLeft
            % end of vector reached
            xExtentLeft = x(ii);
            iExtentLeft = ii;
            noIntercept = false;
            truncLeft = true;
        else
            ii = ii-1;
        end
    end
    
    % right extent
    iLimitRight = numel(y);
    noIntercept = true;
    ii = iPeak;
    while noIntercept
        yii = y(ii);
        if yii <= yInterceptRight
            if (interpolate) && (ii ~= iPeak)
                % interpolate
                iinterp = [ii-1,ii];
                xExtentRight = interp1(y(iinterp),x(iinterp),yInterceptRight);
                iExtentRight = NaN;
            else
                % use vector index
                xExtentRight = x(ii);
                iExtentRight = ii;
            end
            truncRight = false;
            noIntercept = false;
        elseif ii == iLimitRight
            % end of vector reached
            xExtentRight = x(ii);
            iExtentRight = ii;
            noIntercept = false;
            truncRight = true;
        else
            ii = ii+1;
        end
    end

    % output
    xExtents = [xExtentLeft,xExtentRight];
    iExtents = [iExtentLeft,iExtentRight];
    truncated = [truncLeft,truncRight];
end