%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "fitExp"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       Curve Fitting Toolbox
%
%   Description:
%       Applies an exponential curve fit of the form a*exp(b*x) to the
%       peaks of pulses in a click. Pulse peaks are first standardized by 
%       normalizing their amplitudes in the y-axis, and their (approximate) 
%       IPIs in the x-axis.
%
%   Input:
%       xEnv [n-by-1 double]:
%           Vector of waveform envelope amplitudes
%       pulseRanges [2-by-n]:
%           Matrix of start and end samples for each pulse. Columns 
%           represent individual pulses, first row is start
%           samples, and second row is end samples.
%
%   Output:
%       expFitData [1-by-1 struct]:
%           Struct with fields "a", "b", and "r2". These contain the fit 
%           coefficients and r-squared goodness-of-fit. 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function expFitData = fitExp(xEnv,pulseRanges)

    % INITIALIZE VARIABLES
    expFitData = struct('a',NaN,'b',NaN,'r2',NaN);
    nPulses = size(pulseRanges,2);
    % END VARIABLE INITIALIZATIONS

    if nPulses > 1
        % get pulse peaks
        xPulsePeaks = zeros(nPulses,1); % "fit" only takes column vectors
        iPulsePeaks = zeros(nPulses,1);
        for ii = 1:nPulses
            pulseSamplesii = pulseRanges(1,ii):pulseRanges(2,ii);
            [xPulsePeakii,iiPulsePeakii] = max(xEnv(pulseSamplesii));
            xPulsePeaks(ii) = xPulsePeakii;
            iPulsePeaks(ii) = pulseSamplesii(iiPulsePeakii);
        end
        
        % scale peaks
        xPulsePeaks = xPulsePeaks./max(xPulsePeaks);
        
        % scale peak indices to average inter-peak interval
        iPulsePeaks = (iPulsePeaks - min(iPulsePeaks))./mean(diff(iPulsePeaks));
        
        % compute fit
        [fitObj,fitGOF] = fit(iPulsePeaks,xPulsePeaks,'exp1');
        
        % save relevant data
        expFitData.a = fitObj.a;
        expFitData.b = fitObj.b;
        expFitData.r2 = fitGOF.rsquare;
    end
end