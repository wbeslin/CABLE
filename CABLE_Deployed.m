%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "CABLE_Deployed"
%   Written by Wilfried Beslin
%   Last Updated: May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       MATLAB Compiler
%       Statistics and Machine Learning Toolbox
%
%   Description:
%       This is the main function which the deployed (i.e. compiled)
%       version of CABLE should execute. If running CABLE directly from
%       MATLAB, this function can be used too, but is not necessary
%       ("CABLE.CABLE_GUI" can be called directly instead).
%
%   Input: none
%
%   Output: none
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function CABLE_Deployed

    % define pragma for including definition of the click classifier class.
    % This is necessary for compiled apps to recognize SMLT objects.
    % Pragmas are defined with the "%#" flag.
    %#function classreg.learning.classif.CompactClassificationSVM
    
    % run GUI version of CABLE
    CABLE.CABLE_GUI;
end