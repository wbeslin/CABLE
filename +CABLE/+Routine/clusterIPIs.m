%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "clusterIPIs"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       Statistics and Machine Learning Toolbox
%
%   Description:
%       Automatically fits Gaussian mixture models (GMMs) to an IPI 
%       distribution. There are 2 main steps to this: 
%       1) a range for the possible number of clusters is estimated by 
%       applying two Gaussian kernal density estimates (KDEs): one with a 
%       wide SD (lower limit),  and one with a narrow SD (upper limit). 
%       2) GMMs are fitted for each number of clusters in the range, using 
%       the EM algorithm (implemented in the Statistics and Machine 
%       Learning Toolbox).
%
%   Input:
%       IPIs [n-by-1 double]:
%           Vector of IPIs, in milliseconds
%       Fs [1-by-1 double]:
%           Sampling rate, in Hertz
%       KDEBandwidths [1-by-2 double]:
%           Narrow and wide bandwidths used during Gaussian kernel density
%           estimation (KDE). KDE is used to get an initial estimate of the
%           minimum and maximum number of IPI clusters that might be
%           present. Units are in milliseconds.
%       nkExtra [1-by-1 double]:
%           Number of extra clusters to test for beyond the KDE estimates
%       shareSigma [1-by-1 logical]:
%           Specifies if every cluster in a GMM must have the same standard
%           deviation or not
%       sigma2RegVal [1-by-1 double | 'auto']:
%           Cluster variance regularization value; a number added to the 
%           variance of each cluster when fitting GMMs. This parameter can
%           also be set as the string 'auto', in which case cluster
%           variance will be decided automatically based on sampling
%           resolution.
%       EMTol [1-by-1 double]:
%           Tolerance threshold at which point the EM algorithm (used for 
%           fitting GMMs) considers maximum likelihood to have converged
%       maxEMIterations [1-by-1 double]:
%           Maximum number of iterations allowed during EM model fitting
%       maxEMTries [1-by-1 double]:
%           Maximum number of times that the EM algorithm may be rerun in
%           case of failure. Failure can occur due to unsuitable initial
%           conditions.
%
%   Output:
%       GMMs [1-by-n cell]:
%           Cell array containing plausible mixture models, ranked from 
%           most supported to least supported. These are in the form of 
%           "gmdistribution" objects.
%       deltaBICs [1-by-n double]:
%           Vector of Delta BIC values for each mixture model
%       statusMsg [1-by-n char]:
%           String describing if mixture modelling was succcessful or not,
%           and if not, why.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [GMMs,deltaBICs,statusMsg] = clusterIPIs(IPIs,Fs,KDEBandwidths,nkExtra,...
    shareSigma,sigma2RegVal,EMTol,maxEMIterations,maxEMTries)

    % make sure there are at least 2 IPIs
    if numel(IPIs) < 2
        GMMs = cell(1,0);
        deltaBICs = double.empty(1,0);
        statusMsg = 'Not enough data for clustering';
        return
    end

    % INITIALIZE VARIABLES
    if ischar(sigma2RegVal) && strcmp(sigma2RegVal,'auto')
        sigma2RegVal = (1/(Fs/1000)/4)^2; % encompases uncertainty due to sampling rate
    end
    tStep_ms = 1/(Fs/1000);
    tRange = [floor(min(IPIs)-tStep_ms),ceil(max(IPIs)+tStep_ms)];
    %%% establish t vector
    t = (0:tStep_ms:tRange(2))';
    t = t(t >= tRange(1));
    % END VARIABLE INITIALIZATION
 
    % STEP 1) Kernel Density Estimation
    KDEBandwidths = sort(KDEBandwidths,'descend'); % wide bandwidth first
    [KDE,kKDE,tKDEPeaks,aKDEPeaks] = doKDE(KDEBandwidths,IPIs,t);

    % establish k vector, initial sigma, initial mu, and initial p for core k.
    [kCore,mu0Core,pRaw0Core,sigma0Core] = computeCoreInitialConditions(kKDE,tKDEPeaks,aKDEPeaks,KDEBandwidths);
    
    % get extra k's
    kMinCore = min(kCore);
    kMaxCore = max(kCore);
    kUnder = max([1,kMinCore-nkExtra]):(kMinCore-1);
    kOver = kMaxCore + (1:nkExtra);
    nkUnder = numel(kUnder);
    nkOver = numel(kOver);
    kMinAll = min([min(kUnder),kMinCore]);
    kMaxAll = max([max(kOver),kMaxCore]);
    kAll = kMinAll:kMaxAll;
    nkAll = numel(kAll);
    
    % get extra sigma0
    if nkUnder > 0
        sigma0Under = interp1([kUnder(1),kCore(1)],sigma0Core(1).*[2,1],kUnder);
    else
        sigma0Under = [];
    end
    if nkOver > 0
        sigma0Over = interp1([kCore(end),kOver(end)],sigma0Core(end).*[1,0.5],kOver);
    else
        sigma0Over = [];
    end
    sigma0All = [sigma0Under,sigma0Core,sigma0Over];
    sigma0All = max(sigma0All,sqrt(sigma2RegVal)); % to minimize the chance of ill-conditioned variances during EM (not sure if this actually works)
    
    % STEP 2) Mixture Modelling
    % initialize container
    GMMs = cell(1,nkAll);
    isValid = false(1,nkAll);
    
    % loop through each k
    for ii = 1:nkAll
        % loop variables
        kii = kAll(ii);
        isCoreii = ismember(kii,kCore);
        if isCoreii
            maxEMTriesii = 1;
        else
            maxEMTriesii = maxEMTries;
        end
        nEMTriesii = 0;
        solutionFoundii = false;
        
        % start EM try loop
        while ~solutionFoundii && nEMTriesii < maxEMTriesii;
            
            % get initial conditions for current k
            [mu0ii,p0ii,sigma0ii] = getInitialConditions(kii,ii,kCore,t,mu0Core,pRaw0Core,sigma0All);
            
            % run EM
            [GMMii,isValidii,validityMsgii] = CABLE.Routine.fitGMM(IPIs,Fs,kii,mu0ii,sigma0ii,p0ii,shareSigma,sigma2RegVal,EMTol,maxEMIterations);
            if isValidii
                GMMs{ii} = GMMii;
                solutionFoundii = true;
            %else % DEBUG
            %    warning('k = %d, nTries = %d/%d\n%s',kii,nEMTriesii+1,maxEMTriesii,validityMsgii)
            end
            
            % increment nEMTries
            nEMTriesii = nEMTriesii + 1;
        end
        
        % examine and save validity
        if ~solutionFoundii
            warning('GMM invalid (k = %d, shared sigma = %d)\n%s',kii,shareSigma,validityMsgii)
        end
        isValid(ii) = isValidii;
    end
    
    % remove invalid GMMs
    GMMs = GMMs(isValid);
    
    % rank GMMs by BIC
    [GMMs,deltaBICs] = rankGMMs(GMMs);
    
    % get status
    if isempty(GMMs)
        statusMsg = 'All GMM fitting attempts unsuccessful';
    else
        statusMsg = 'Clustering successful';
    end
end

%% doKDE ------------------------------------------------------------------
function [KDE,KDEk,tKDEPeaks,aKDEPeaks] = doKDE(KDEBandwidths,IPIs,t)
% Runs kernel density estimation, and returns the resulting functions as
% well as peaks found within. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % initialize variables
    nKDEs = numel(KDEBandwidths);
    KDE = zeros(numel(t),nKDEs);
    KDEk = zeros(1,nKDEs);
    tKDEPeaks = cell(1,nKDEs);
    aKDEPeaks = cell(1,nKDEs);

    % do KDEs
    for ii = 1:nKDEs
        bwii = KDEBandwidths(ii);

        % KDE
        KDEii = ksdensity(IPIs,t,'bandwidth',bwii);
        KDE(:,ii) = KDEii;

        % get peaks
        [aPeaksii,iPeaksii] = findpeaks(KDEii);
        if isempty(aPeaksii)
            [aPeaksii,iPeaksii] = max(KDEii);
        end
        tPeaksii = t(iPeaksii);
        aKDEPeaks{ii} = aPeaksii;
        tKDEPeaks{ii} = tPeaksii;
        KDEk(ii) = numel(aPeaksii);
    end
end

%% computeCoreInitialConditions -------------------------------------------
function [k,mu0,pRaw0,sigma0] = computeCoreInitialConditions(kKDE,tKDEPeaks,aKDEPeaks,KDEBandwidths)
% Returns the k vector for the KDE-determined cluster count range, as well 
% as initial estimates of parameters for each cluster.
% mu0 and pRaw0 are both cell arrays containing vectors for each k.
% sigma0 is a vector.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if numel(kKDE) == 1
        % only one k - easy
        k = kKDE;
        mu0 = tKDEPeaks;
        sigma0 = KDEBandwidths;
        pRaw0 = aKDEPeaks;
    else
        % two k - more complex
        % isolate KDE peaks. ASSUMING NARROW BANDWIDTH IS 2nd COLUMN
        tPeaksNarrow = tKDEPeaks{:,2};
        aPeaksNarrow = aKDEPeaks{:,2};
        tPeaksWide = tKDEPeaks{:,1};
        
        % establish k vector
        kMin = min(kKDE);
        kMax = max(kKDE);
        k = kMin:kMax;
        nk = numel(k);
        
        if nk > 1
            % find smallest separation of each peak. 
            % This will be used later to determine at which k each peak 
            % should be added, based on sparseness: the most isolated peaks 
            % are added first. This is because peaks that are closer 
            % together are more likely to be merged at low k.
            % The final peak locations for each k are all taken from the 
            % narrow bandwidth KDE, but the wide bandwidth peaks are used 
            % to determine which ones should be included for the lowest k.
            narrowPeakDiffs = diff(tPeaksNarrow);
            peakMinSep = zeros(kMax,1);
            peakMinSep(1) = narrowPeakDiffs(1);
            peakMinSep(end) = narrowPeakDiffs(end);
            for ii = 2:(kMax-1)
                peakMinSep(ii) = min([narrowPeakDiffs(ii-1),narrowPeakDiffs(ii)]);
            end
            %%% rank peaks by sparsness
            [~,iPeakSort] = sort(peakMinSep,'descend');
            tPeaksNarrowSparsest = tPeaksNarrow(iPeakSort);
            aPeaksNarrowSparsest = aPeaksNarrow(iPeakSort);
            %%% for smallest k, take peaks that are closest to wide KDE peaks
            [tPeaksNarrowNearWide,iPeaksNarrowNearWide] = CABLE.Utilities.nearestValue(tPeaksNarrow,tPeaksWide);
            aPeaksNarrowNearWide = aPeaksNarrow(iPeaksNarrowNearWide);
            %%% remove those peaks from the sparsness vector
            iKeep = ~ismember(tPeaksNarrowSparsest,tPeaksNarrowNearWide);
            tPeaksNarrowSparsest = tPeaksNarrowSparsest(iKeep);
            aPeaksNarrowSparsest = aPeaksNarrowSparsest(iKeep);
            %%% loop through each k and select peaks to use
            kPeaks = cell(1,nk);
            kPeakAmplitudes = cell(1,nk);
            kPeaks{1} = tPeaksNarrowNearWide;
            kPeakAmplitudes{1} = aPeaksNarrowNearWide;
            for ii = 1:(nk-1)
                % peak locations (mu)
                kPeaksii = [tPeaksNarrowNearWide;tPeaksNarrowSparsest(1:ii)];
                kPeaks{ii+1} = kPeaksii;
                % peak amplitudes (p)
                kPeakAmplitudesii = [aPeaksNarrowNearWide;aPeaksNarrowSparsest(1:ii)];
                kPeakAmplitudes{ii+1} = kPeakAmplitudesii;
            end

            % save output
            mu0 = kPeaks;
            sigma0 = interp1(kKDE,KDEBandwidths,k);
            pRaw0 = kPeakAmplitudes;
        else
            % special processing in case both KDEs have the same number of 
            % peaks. This can happen when clusters are far apart.
            mu0 = {tPeaksNarrow};
            sigma0 = mean(KDEBandwidths);
            pRaw0 = {aPeaksNarrow};
        end
    end
end

%% getInitialConditions ---------------------------------------------------
function[mu0,p0,sigma0] = getInitialConditions(k,ik,kCore,t,mu0Core,pRaw0Core,sigma0All)
% Returns the appropriate initial means, SDs, and priors for current k.
% If k is beyond the lower KDE limit, clusters are removed at random.
% If k is beyond the upper KDE limit, clusters are added at random.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
    if k < min(kCore)
        % underestimate - remove clusters
        
        % initialize variables
        kBase = min(kCore);
        kDiff = diff([k,kBase]);
        tPeaksBase = mu0Core{1};
        aPeaksBase = pRaw0Core{1};
        
        % remove clusters
        iKeep = randperm(kBase,kBase-kDiff);
        mu0 = tPeaksBase(iKeep);
        pRaw0 = aPeaksBase(iKeep);
        
    elseif k > max(kCore)
        % overestimate - add clusters
        
        % initialize variables
        kBase = max(kCore);
        kDiff = diff([kBase,k]);
        tPeaksBase = mu0Core{end};
        aPeaksBase = pRaw0Core{end};
        maxPeak = max(aPeaksBase);
        peakMult = 1.5;
        
        % add clusters
        tPeaksAdd = t(randi(numel(t),kDiff,1));
        aPeaksAdd = rand(kDiff,1)*maxPeak*peakMult;
        mu0 = [tPeaksBase;tPeaksAdd];
        pRaw0 = [aPeaksBase;aPeaksAdd];
    else
        lCore = ismember(kCore,k);
        mu0 = mu0Core{lCore};
        pRaw0 = pRaw0Core{lCore};
    end
    
    % normalize p
    p0 = pRaw0/sum(pRaw0);
    
    % get sigma
    sigma0 = sigma0All(ik);
end

%% rankGMMs ---------------------------------------------------------------
function [GMMsRanked,deltaBICsRanked] = rankGMMs(GMMs)
% Ranks GMMs according to BIC. Lower deltaBIC is better.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % initialize variables
    nGMMs = numel(GMMs);
    BICs = NaN(1,nGMMs);
    
    % loop through each model and get BIC
    for ii = 1:nGMMs
        BICs(ii) = GMMs{ii}.BIC;
    end
    
    % get deltaBICs
    deltaBICs = BICs - min(BICs);
    
    % rank models
    [deltaBICsRanked,iRank] = sort(deltaBICs,'ascend');
    GMMsRanked = GMMs(iRank);
end