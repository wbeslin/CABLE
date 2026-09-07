%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "fitGMM"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       Statistics and Machine Learning Toolbox
%
%   Description:
%       Fits a Gaussian mixture model (GMM) to an IPI vector, and returns 
%       it as a "gmdistribution" object (from the Statistics and Machine 
%       Learning toolbox). It is basically an interface to the toolbox's
%       "fitgmdist" function for 1-D clustering with predefined initial 
%       parameters. It also checks that the model is valid, which requires 
%       that:
%           1) it exist (i.e. EM did not fail) 
%           2) maximum likelihood converged
%           3) it has no insignificantly small clusters (p < 1e-3)
%           4) each cluster has a unique mu (no redundancy)
%           
%   Input:
%       IPIs [n-by-1 double]:
%           Vector of IPIs
%       Fs [1-by-1 double]:
%           Sampling rate, in Hertz
%       k [1-by-1 double]:
%           Number of clusters in the model
%       mu0 [1-by-n double]:
%           Initial cluster means
%       sigma0 [1-by-n OR 1-by-1 double]:
%           Initial cluster standard deviations (not variance). If this is
%           a scalar, all clusters will start assuming the same value.
%       p0 [1-by-n double]:
%           Initial proportions of each cluster
%       shareSigma [1-by-1 logical]:
%           Specifies if all clusters must have the same standard deviation
%           or not
%       sigma2RegVal [1-by-1 double]:
%           Variance regularization value. This is a small number that is
%           systematically added to the VARIANCE of each cluster during the
%           EM algorithm. Its main purpose is to avoid numerical 
%           instabilities caused by variances of 0, but it can also be seen
%           as a "prior" over the variance.
%       EMTol [1-by-1 double]:
%           Tolerance threshold at which point the EM algorithm (used for 
%           fitting GMMs) considers maximum likelihood to have converged
%       maxEMIterations [1-by-1 double]:
%           Maximum number of EM iterations allowed. If a stable maximum
%           likelihood has not been found within this number of iterations,
%           the model will be marked as invalid.
%
%   Output:
%       GMM [1-by-1 gmdistribution]:
%           Gaussian mixture model obtained by EM
%       isValid [1-by-1 logical]:
%           Specifies if the model is valid or not
%       validityMsg [1-by-n OR 0-by-0 char]:
%           If the model is invalid, this string describes why.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [GMM,isValid,validityMsg] = fitGMM(IPIs,Fs,k,mu0,sigma0,p0,shareSigma,sigma2RegVal,EMTol,maxEMIterations)

    % Prepare parameters for GMM fitting.
    % "fitgmdist" is very picky about how initial conditions are specified:
    % - Means (mu) must be k-by-d (column vector in this case)
    % - For SD (sigma), it takes (co)variance, so sigma should be squared 
    %   (unfortunately the gmdistribution class also calls the variance 
    %   "Sigma"). If "SharedCovariance" is false, input must be a depth 
    %   vector in this case. (d-by-d-by-k). Otherwise, it must be scalar.
    % - Component proportions (p) are always a row vector (1-by-k).

    % Ensure means are a column vector
    mu0 = reshape(mu0,numel(mu0),1);

    % Process SD
    if ~shareSigma
        if isscalar(sigma0)
            %%% repeat sigma0 as depth vector if scalar
            sigma0 = repelem(sigma0,1,1,k);
        else
            %%% reshape to depth vector
            sigma0 = reshape(sigma0,1,1,k);
        end
    end
    %%% convert to variance
    sigma20 = sigma0.^2;

    % Ensure proportions are a row vector
    p0 = reshape(p0,1,numel(p0));

    % create initial values struct
    startData = struct('mu',mu0,'Sigma',sigma20,'ComponentProportions',p0);

    % Set options
    verbose = 'off';
    EMOpts = statset('Display',verbose,'MaxIter',maxEMIterations,'TolFun',EMTol);

    % run EM
    try
        GMM = fitgmdist(IPIs,k,'SharedCovariance',shareSigma,'Start',startData,...
            'RegularizationValue',sigma2RegVal,'Options',EMOpts);
        errMsg = '';
    catch ME
        GMM = gmdistribution();
        errMsg = ME.message;
    end
    
    % assess validity
    [isValid,validityMsg] = assessModelValidity(GMM,Fs,errMsg);
end

%% assessModelValidity ----------------------------------------------------
function [isValid,validityMsg] = assessModelValidity(GMM,Fs,errMsg)
% Returns a logical and message indicating if a GMM is valid or not.
% Valid models are those that: 
%   1) exist (i.e. the fit succeeded) 
%   2) converged
%   3) have no insignificant clusters (clusters with p < 1e-3)
%   4) have no redundant clusters (clusters with same mu)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % initialize variables
    tStep = 1/(Fs/1000);
    pThresh = 1e-3;
    
    
    % 1) check existence
    EMFailed = GMM.NumComponents == 0;
    if EMFailed
        isValid = false;
        validityMsg = sprintf('EM failed: %s',errMsg);
        return
    end
        
    % 2) check convergence
    didntConverge = ~GMM.Converged;
    if didntConverge
        isValid = false;
        validityMsg = 'Did not convergence';
        return
    end
        
    % 3) check significance
    insignificant = any(GMM.ComponentProportion < pThresh);
    if insignificant
        isValid = false;
        validityMsg = 'Insignificant clusters';
        return
    end
        
    % 4) check redundancy
    redundant = any(diff(sort(GMM.mu)) < tStep);
    if redundant
        isValid = false;
        validityMsg = 'Redundant clusters';
        return
    end
        
    % At this point, all checks were passed, so set validity to true
    isValid = true;
    validityMsg = '';
end