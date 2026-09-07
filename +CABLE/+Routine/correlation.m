%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "correlation"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies: 
%       none
%
%   Description:
%       Returns the correlation between two vectors. Both row and column 
%       vectors are supported, but the two must have the same number of 
%       elements. Use this in a loop while lagging one of the vectors to 
%       get the cross-correlation function.
%
%   Input:
%       x [n-by-1 OR 1-by-n double]: 
%           First data vector
%       y [n-by-1 OR 1-by-n double]: 
%           Second data vector
%
%   Output:
%       c [1-by-1 double]:
%           Correlation between "x" and "y"
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function c = correlation(x,y)

    % force inputs into row vectors (also doubles as input validation)
    n = length(x);
    x = reshape(x,[1,n]);
    y = reshape(y,[1,n]);

    % correlation
    c = sum(prod([x;y])) / sqrt(sum(x.*x)*sum(y.*y));
end