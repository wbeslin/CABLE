%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "nearestValue"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies: 
%       none
%
%   Description:
%       Returns the values and indices of those values in vector A that are 
%       closest to the values in vector B. If A has multiple values that 
%       are equally close to a value in B, only the index of the first find 
%       is returned. 
%
%   Input:
%       A [1-by-n OR n-by-1 double]:
%           Vector containing the desired values
%       B [1-by-n OR n-by-1 double]:
%           Vector containing the values from which the nearest values in
%           "A" are requested
%
%   Output:
%       val [1-by-n OR n-by-1 double]:
%           Values of "A" that are closest to the values of "B"
%       ind [1-by-n OR n-by-1 double]:
%           Index of the values in "A" that are closest to the values of 
%           "B"
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [val,ind] = nearestValue(A,B)

sB = size(B);
nB = numel(B);
val = zeros(sB);
ind = zeros(sB);
for ii = 1:nB
    [~,indii] = min(abs(A - B(ii))); % "min" returns only the first find
    val(ii) = A(indii);
    ind(ii) = indii;
end