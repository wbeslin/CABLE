%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "main"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       Signal Processing Toolbox
%       Parallel Computing Toolbox
%
%   Description:
%       This is the main function that executes the IPI compilation and
%       clustering routine. It takes input files and parameters, processes
%       IPIs, and returns output.
%
%   Input: 
%       All the following inputs are required and must be set as Name-Value
%       pairs.
%       inputFiles [n-by-1 cell]:
%           Cell array containing one or more strings describing paths to 
%           input files. If there are multiple paths, the files will be 
%           merged (only supported for audio files).
%       monitor [1-by-1 StatusMonitor]:
%           StatusMonitor object for displaying progress to the user
%       classFile [1-by-n char]:
%           String pointing to the click classifier file
%       doDebug [1-by-1 logical]:
%           Specifies if extra output should be returned, useful for
%           debugging purposes
%       doAllIPIs [1-by-1 logical]:
%           Specifies if data on all IPIs should be returned or not
%       doFilteredIPIs [1-by-1 logical]:
%           Specifies if filtered IPI data should be returned or not
%       doClusters [1-by-1 logical]:
%           Specifies if IPI clustering data should be returned or not
%       nIPIReps [1-by-1 double]:
%           The number of local IPI repetitions needed for an IPI to be
%           considered valid
%       minGoodProb [1-by-1 double]:
%           The minimum probability of being "Good" that a click must have 
%           to be classified as "Good"
%       recSplitDuration [1-by-1 double]:
%           Duration at which to split audio files into segments, in
%           minutes
%       minSegmentDuration [1-by-1 double]:
%           Minimum allowed duration of an audio segment, in minutes
%       channelIndex [1-by-1 double]:
%           For audio file inputs, this is the channel number from which to
%           extract samples
%       threshOn [1-by-1 double]:
%           Linear SNR threshold which controls the onset of click 
%           detection events
%       threshOff [1-by-1 double]:
%           Linear SNR threshold which dictates the limits of a click range
%       alphaSignal [1-by-1 double]:
%           Smoothing factor for the exponential signal power estimation 
%           filter used for click detection
%       alphaNoiseOn [1-by-1 double]:
%           Smoothing factor for the exponential noise power estimation
%           filter, used while a click has been detected
%       alphaNoiseOff [1-by-1 double]:
%           Smoothing factor for the exponential noise power estimation 
%           filter, used while only noise is present
%       minEchoProp [1-by-1 double]:
%           Minimum proportion of a click envelope peak beyond which the 
%           next click will be considered an echo
%       IPIRange [1-by-2 double]:
%           The minimum and maximum IPI limits, in milliseconds
%       maxClickDuration [1-by-1 double]:
%           Maximum allowed duration of a click, in milliseconds
%       minClickSep [1-by-1 double]:
%           Minimum expected separation between clicks, in milliseconds.
%           Use only if there is just one whale present.
%       tukeyFalloffDuration [1-by-1 double]:
%           The extent of the falloff regions of each Tukey window, in
%           milliseconds
%       pulseDurationRange [1-by-2 double]:
%           The minimum and maximum expected duration of individual pulses
%           within sperm whale clicks, in milliseconds
%       smoothBandwidths [1-by-n double]:
%           Vector of bandwidths to use for waveform envelope smoothing
%           during pulse detection, from narrowest to widest. Units are in 
%           milliseconds.
%       nSmoothRuns [1-by-1 double]:
%           Number of times to run the envelope smoothing filter in 
%           succession during pulse detection
%       peakBaseHeightProp [1-by-1 double]:
%           Proportion of the peak-to-base height of a pulse to use as the 
%           reference point for estimating pulse duration
%       promThreshProp [1-by-1 double]:
%           Proportion of the difference between the prominences of the
%           most and least prominent peaks in a smoothed envelope. This is
%           used to determine the minimum prominence that a peak may have
%           to indicate the presence of a pulse.
%       minPromThreshScale [1-by-1 double]:
%           Scale factor relative to the RMS of the absolute value of the
%           difference between successive samples in the unsmoothed
%           envelope. This is used as a threshold to distinguish peaks of
%           signals from peaks that likely arise only from noise.
%       maxIPIDeviation [1-by-1 double]:
%           The maximum acceptable difference between the IPI values of a
%           click that were computed using different methods (i.e. 
%           autocorrelation and cepstrum). This parameter is what controls 
%           IPI precision.
%       doIPIMethod [1-by-1 struct]:
%           Struct with field names corresponding to each IPI computation
%           method (i.e. "Autocorrelation" and "Cepstrum"). Each field
%           contains a logical that dictates if that method should be used
%           or not.
%       useChiSquared [1-by-1 struct]:
%           Struct with field names corresponding to each IPI computation
%           method (i.e. "Autocorrelation" and "Cepstrum"). Each field
%           contains a logical that dictates if Chi-Squared type windows
%           should be applied to each click before IPI calculation, in 
%           order to amplify the signal of decaying pulses (Goold, 1996).
%       ICIRange [1-by-2 double]:
%           The minimum and maximum inter-click interval (ICI) limits 
%           within which successive clicks are searched for. This is used 
%           when checking for IPI repetitions.
%       ICITol [1-by-1 double]:
%           The maximum expected difference in ICI between successive
%           clicks in a click train. This is used only when checking for 2
%           or more IPI repetitions. Units are in seconds.
%       IPITol [1-by-1 double]:
%           The maximum expected difference in IPI between successive
%           clicks in a click train. This is used when checking for IPI
%           repetitions. Units are in milliseconds.
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
%           case of failure
%
%   Output:
%       IPIData [1-by-1 struct]:
%           struct containing specified output options
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DEV NOTES:
%   - Parameter "doDebug" is a special output option not available in the 
%       GUI. If true, will force "doAllIPIs" to be true, and will append
%       extra data to that output. Only works for audio and "Clicks" input
%       types.
%   - Input type "Clicks" was added to support my old object-oriented
%       data structure. It is irrelevant to the public release.
%   - Because of the way the program has evolved (particularly in relation
%       to support for new input types), the code here is rather inelegant.
%       It would be nice to cut down the number of switch-case and if- 
%       statements.

function IPIData = main(varargin)

    % PARSE INPUT
    p = inputParser;
    p.CaseSensitive = true;
    p.PartialMatching = false;
    p.addParameter('inputFiles',[])
    p.addParameter('monitor',[])
    p.addParameter('classFile',[])
    p.addParameter('doDebug',[])
    p.addParameter('doAllIPIs',[])
    p.addParameter('doFilteredIPIs',[])
    p.addParameter('doClusters',[])
    p.addParameter('nIPIReps',[])
    p.addParameter('minGoodProb',[])
    p.addParameter('recSplitDuration',[])
    p.addParameter('minSegmentDuration',[])
    p.addParameter('channelIndex',[])
    p.addParameter('threshOn',[])
    p.addParameter('threshOff',[])
    p.addParameter('alphaSignal',[])
    p.addParameter('alphaNoiseOn',[])
    p.addParameter('alphaNoiseOff',[])
    p.addParameter('minEchoProp',[])
    p.addParameter('IPIRange',[])
    p.addParameter('maxClickDuration',[])
    p.addParameter('minClickSep',[])
    p.addParameter('tukeyFalloffDuration',[])
    p.addParameter('pulseDurationRange',[])
    p.addParameter('smoothBandwidths',[])
    p.addParameter('nSmoothRuns',[])
    p.addParameter('peakBaseHeightProp',[])
    p.addParameter('promThreshProp',[])
    p.addParameter('minPromThreshScale',[])
    p.addParameter('maxIPIDeviation',[])
    p.addParameter('doIPIMethod',[])
    p.addParameter('useChiSquared',[])
    p.addParameter('ICIRange',[])
    p.addParameter('ICITol',[])
    p.addParameter('IPITol',[])
    p.addParameter('KDEBandwidths',[])
    p.addParameter('nkExtra',[])
    p.addParameter('shareSigma',[])
    p.addParameter('sigma2RegVal',[])
    p.addParameter('EMTol',[])
    p.addParameter('maxEMIterations',[])
    p.addParameter('maxEMTries',[])
    p.parse(varargin{:})
    
    % make sure everything was set
    if ~isempty(p.UsingDefaults)
        error('Missing the following inputs:\n%s',strjoin(p.UsingDefaults))
    end
    
    % assign variables
    inputFiles = p.Results.inputFiles;
    monitor = p.Results.monitor;
    classFile = p.Results.classFile;
    doDebug = p.Results.doDebug;
    doAllIPIs = p.Results.doAllIPIs;
    doFilteredIPIs = p.Results.doFilteredIPIs;
    doClusters = p.Results.doClusters;
    nIPIReps = p.Results.nIPIReps;
    minGoodProb = p.Results.minGoodProb;
    recSplitDuration = p.Results.recSplitDuration;
    minSegmentDuration = p.Results.minSegmentDuration;
    channelIndex = p.Results.channelIndex;
    threshOn = p.Results.threshOn;
    threshOff = p.Results.threshOff;
    alphaSignal = p.Results.alphaSignal;
    alphaNoiseOn = p.Results.alphaNoiseOn;
    alphaNoiseOff = p.Results.alphaNoiseOff;
    minEchoProp = p.Results.minEchoProp;
    IPIRange = p.Results.IPIRange;
    maxClickDuration = p.Results.maxClickDuration;
    minClickSep = p.Results.minClickSep;
    tukeyFalloffDuration = p.Results.tukeyFalloffDuration;
    pulseDurationRange = p.Results.pulseDurationRange;
    smoothBandwidths = p.Results.smoothBandwidths;
    nSmoothRuns = p.Results.nSmoothRuns;
    peakBaseHeightProp = p.Results.peakBaseHeightProp;
    promThreshProp = p.Results.promThreshProp;
    minPromThreshScale = p.Results.minPromThreshScale;
    maxIPIDeviation = p.Results.maxIPIDeviation;
    doIPIMethod = p.Results.doIPIMethod;
    useChiSquared = p.Results.useChiSquared;
    ICIRange = p.Results.ICIRange;
    ICITol = p.Results.ICITol;
    IPITol = p.Results.IPITol;
    KDEBandwidths = p.Results.KDEBandwidths;
    nkExtra = p.Results.nkExtra;
    shareSigma = p.Results.shareSigma;
    sigma2RegVal = p.Results.sigma2RegVal;
    EMTol = p.Results.EMTol;
    maxEMIterations = p.Results.maxEMIterations;
    maxEMTries = p.Results.maxEMTries;
    
    clear p
    % END INPUT PARSING
    
    % initialize variables
    IPIData = struct();
    Fs = 48000;
    if doDebug
        doAllIPIs = true;
    end
    % end variable initialization
    
    % check input type
    [inputType,inputData] = findInputType(inputFiles);
    monitor.setFileType(inputType)
    switch inputType
        case {'AudioFile','AudioArray','AllIPIs','Clicks'}
        
            % Process audio input
            if strcmp(inputType,'AudioFile') || strcmp(inputType,'AudioArray') || strcmp(inputType,'Clicks')
                % 0) More initializations
                parPoolObj = gcp('nocreate');
                doParallel = ~isempty(parPoolObj);
                [noiseFilter,freqBand] = createNoiseFilter(Fs);
                nTukeyFalloff = round(tukeyFalloffDuration*(Fs/1000));
                minPulseDuration = pulseDurationRange(1);
                maxPulseDuration = pulseDurationRange(2);
                minPulseSep = IPIRange(1) - maxPulseDuration;
                load(classFile,'clickClassifier')
                classifierGoodClass = strcmp(clickClassifier.ClassNames,'Good');

                % 1) process audio input (break long files into segments)
                monitor.setMessage('Breaking up time series');
                if ~strcmp(inputType,'Clicks')
                    % get extraction ranges from standard audio files
                    [recSampleRanges,recTimeRanges,recIndices] = CABLE.Routine.parseAudioInput(inputFiles,recSplitDuration,minSegmentDuration);
                else
                    % 'Clicks' object: get full waveform range
                    %%% make sure sampling rate is OK
                    if inputData.Fs ~= Fs
                        error('Incompatible sampling rate')
                    end
                    %%% get whole waveform range
                    recSampleRanges = [1,numel(inputData.x)];
                    recTimeRanges = (recSampleRanges - 1)/Fs;
                    recIndices = 1;
                end
                nWavSegments = numel(recIndices);
                tRangeTotal = [min(recTimeRanges(:)),max(recTimeRanges(:))];
                
                %%% initialize container cells.
                %%% Content dimensions are important, hence the calls to 
                %%% <class>.empty
                allIPIs = repmat({double.empty(0,1)},nWavSegments,1);
                tOccurrence = repmat({double.empty(0,1)},nWavSegments,1); %cell(nWavSegments,1);
                classifierScores = repmat({double.empty(0,1)},nWavSegments,1); %cell(nWavSegments,1);
                %passedClassifierTest = cell(nWavSegments,1);
                passedPrecisionTest = repmat({logical.empty(0,1)},nWavSegments,1); %cell(nWavSegments,1);
                isGood = repmat({logical.empty(0,1)},nWavSegments,1); %cell(nWavSegments,1);
                if doDebug
                    classifierLabels = repmat({cell.empty(0,1)},nWavSegments,1); %cell(nWavSegments,1);                    
                    peakSNR = repmat({double.empty(0,1)},nWavSegments,1); %cell(nWavSegments,1);
                    clickRanges = repmat({double.empty(0,2)},nWavSegments,1); %cell(nWavSegments,1);
                    x = repmat({double.empty(0,1)},nWavSegments,1); %cell(nWavSegments,1);
                end
                %%% update monitor
                monitor.setSegmentCount(nWavSegments);

                for ii = 1:nWavSegments
                    monitor.newSegment()

                    % initialize loop variables
                    recIndexii = recIndices(ii);
                    recii = inputFiles{recIndexii};
                    recSampleRangeii = recSampleRanges(ii,:);
                    %recDurationii = duration(0,0,diff(recSampleRangeii)/Fs)
                    recTimeRangeii = recTimeRanges(ii,:);
                    recDurationii = duration(0,0,diff(recTimeRangeii));
                    tStartii = recTimeRangeii(1);

                    % update monitor
                    monitor.setSegmentDuration(recDurationii);

                    if ~strcmp(inputType,'Clicks')
                        % 2) import audio
                        monitor.setMessage('Loading audio');
                        xii = CABLE.Routine.importAudio(recii,recSampleRangeii,channelIndex,Fs);

                        % 3) apply noise filter
                        monitor.setMessage('Applying noise filter');
                        xii = filtfilt(noiseFilter,xii);
                        if doDebug
                            x{ii} = xii;
                        end

                        % 4) compute Hilbert envelope
                        monitor.setMessage('Computing Hilbert envelope');
                        xEnvii = abs(hilbert(xii));

                        % 5) do click detection
                        monitor.setMessage('Detecting clicks');
                        [clickRangesii,pageNoiseii] = CABLE.Routine.detectClicks(xEnvii,Fs,...
                            threshOn,threshOff,alphaSignal,alphaNoiseOn,alphaNoiseOff,minEchoProp,IPIRange,maxClickDuration,minClickSep,minPulseDuration);
                    else
                        % 'Clicks' object: extract existing waveform and click ranges
                        xii = inputData.x;
                        xEnvii = inputData.xEnv;
                        clickRangesii = inputData.clickRanges;
                        pageNoiseii = inputData.noise;
                    end
                    nClicksii = size(clickRangesii,2);
                    monitor.setSegmentClicksFound(nClicksii);

                    %%% if there are no clicks, ignore this segment and go to the next
                    if nClicksii == 0
                        monitor.endSegment()
                        continue
                    end

                    %%% get click-dependent variables
                    tOccurrenceii = (((clickRangesii(1,:) - 1)/Fs) + tStartii)';
                    nfftii = getNFFT(clickRangesii,nTukeyFalloff,Fs,IPIRange);
                    [xSubii,xEnvSubii,pageNoiseSubii,clickRangesSubii] = getClickWavSegments(xii,xEnvii,pageNoiseii,clickRangesii);

                    % 6) extract features
                    monitor.setMessage('Preparing feature extraction');
                    featuresii = cell(nClicksii,1);
                    
                    %%% get estimate of variation in envelope, for determining pulse detection
                    %%% prominence threshold later
                    minPromThreshii = minPromThreshScale*rms(abs(diff(xEnvii)));
                    
                    %%% feature extraction
                    if doParallel
                        % Parallel version
                        %%% Request "nClicksii" evaluations of extractFeatures to be
                        %%% sent to workers in the parallel pool, using "parfeval"
                        for jj = 1:nClicksii
                            xjj = xSubii{jj};
                            xEnvjj = xEnvSubii{jj};
                            pageNoisejj = pageNoiseSubii{jj};
                            clickRangejj = clickRangesSubii(:,jj);
                            feFuture(jj) = parfeval(parPoolObj,@CABLE.Routine.extractFeatures,1,...
                                xjj,xEnvjj,Fs,clickRangejj,pageNoisejj,...
                                minPulseDuration,maxPulseDuration,minPulseSep,smoothBandwidths,nSmoothRuns,peakBaseHeightProp,promThreshProp,minPromThreshii,...
                                nfftii,nTukeyFalloff);
                        end
                        %%% Collect results as they become available
                        for jj = 1:nClicksii
                            [jjComplete,featuresjj] = fetchNext(feFuture);
                            featuresii{jjComplete} = featuresjj;
                            try
                                monitor.setMessage(sprintf('Extracted features from click %d',jjComplete));
                            catch ME
                                cancel(feFuture)
                                rethrow(ME)
                            end
                        end
                        %%% clear the FevalFuture object
                        clear feFuture
                    else
                        % Serial version
                        for jj = 1:nClicksii
                            xjj = xSubii{jj};
                            xEnvjj = xEnvSubii{jj};
                            pageNoisejj = pageNoiseSubii{jj};
                            clickRangejj = clickRangesSubii(:,jj);
                            featuresjj = CABLE.Routine.extractFeatures(...
                                xjj,xEnvjj,Fs,clickRangejj,pageNoisejj,...
                                minPulseDuration,maxPulseDuration,minPulseSep,smoothBandwidths,nSmoothRuns,peakBaseHeightProp,promThreshProp,minPromThreshii,...
                                nfftii,nTukeyFalloff);
                            featuresii{jj} = featuresjj;
                            monitor.setMessage(sprintf('Extracted features from click %d',jj));
                        end
                    end
                    
                    % 6.1) get peakSNR if debug mode is on
                    if doDebug
                        peakSNRii = NaN(nClicksii,1);
                        for jj = 1:nClicksii
                            xEnvjj = xEnvSubii{jj};
                            pageNoisejj = pageNoiseSubii{jj};
                            clickRangejj = clickRangesSubii(:,jj);
                            peakSNRjj = getPeakSNR(xEnvjj,pageNoisejj,clickRangejj);
                            peakSNRii(jj) = peakSNRjj;
                            monitor.setMessage(sprintf('Computed peak SNR for click %d',jj))
                        end
                    end

                    % 7) classify clicks
                    monitor.setMessage('Classifying clicks');
                    featuresii = cell2mat(featuresii);
                    [classifierLabelsii,classifierScoresii] = clickClassifier.predict(featuresii);
                        classifierScoresii = classifierScoresii(:,classifierGoodClass);
                        passedClassifierTestii = classifierScoresii >= minGoodProb;

                    % 8) Compute IPIs
                    monitor.setMessage('Preparing IPI calculation');
                    %%% initialize
                    IPIsii = NaN(nClicksii,1);
                    passedPrecisionTestii = false(nClicksii,1);
                    if doAllIPIs
                        iIPIsToComputeii = (1:nClicksii)';
                    else
                        iIPIsToComputeii = find(passedClassifierTestii);
                    end
                    nIPIsToComputeii = numel(iIPIsToComputeii);
                    if doParallel
                        % Parallel version
                        %%% Request "nIPIsToComputeii" evaluations of computeIPI to be
                        %%% sent to workers in the parallel pool, using "parfeval"
                        for jj = 1:nIPIsToComputeii
                            ijj = iIPIsToComputeii(jj);
                            xjj = xSubii{ijj};
                            clickRangejj = clickRangesSubii(:,ijj);
                            cipiFuture(jj) = parfeval(parPoolObj,@CABLE.Routine.computeIPI,2,...
                                xjj,Fs,clickRangejj,...
                                IPIRange,maxIPIDeviation,doIPIMethod,useChiSquared,...
                                nfftii,nTukeyFalloff,freqBand);
                        end
                        %%% Collect results as they become available
                        for jj = 1:nIPIsToComputeii
                            [jjComplete,IPIjj,passedPrecisionTestjj] = fetchNext(cipiFuture);
                            ijjComplete = iIPIsToComputeii(jjComplete);
                            IPIsii(ijjComplete) = IPIjj;
                            passedPrecisionTestii(ijjComplete) = passedPrecisionTestjj;
                            try
                                monitor.setMessage(sprintf('Computed IPI for click %d',ijjComplete));
                            catch ME
                                cancel(cipiFuture)
                                rethrow(ME)
                            end
                        end
                        %%% clear the FevalFuture object
                        clear cipiFuture
                    else
                        % Serial version
                        for jj = 1:nIPIsToComputeii
                            ijj = iIPIsToComputeii(jj);
                            xjj = xSubii{ijj};
                            clickRangejj = clickRangesSubii(:,ijj);
                            [IPIjj,passedPrecisionTestjj] = CABLE.Routine.computeIPI(...
                                xjj,Fs,clickRangejj,...
                                IPIRange,maxIPIDeviation,doIPIMethod,useChiSquared,...
                                nfftii,nTukeyFalloff,freqBand);
                            IPIsii(ijj) = IPIjj;
                            passedPrecisionTestii(ijj) = passedPrecisionTestjj;
                            monitor.setMessage(sprintf('Computed IPI for click %d',ijj));
                        end
                    end

                    % save segment data
                    allIPIs{ii} = IPIsii;
                    tOccurrence{ii} = tOccurrenceii;
                    classifierScores{ii} = classifierScoresii;
                    %passedClassifierTest{ii} = passedClassifierTestii;
                    passedPrecisionTest{ii} = passedPrecisionTestii;
                    isGood{ii} = passedClassifierTestii & passedPrecisionTestii;
                    %monitor.setSegmentClicksPassed(sum(isGood{ii}));
                    if doDebug
                        classifierLabels{ii} = classifierLabelsii;
                        peakSNR{ii} = peakSNRii;
                        clickRanges{ii} = (clickRangesii + recSampleRangeii(recIndexii,1) - 1)';
                    end
                    monitor.endSegment()
                end

                % merge data from each segment
                allIPIs = cell2mat(allIPIs);
                tOccurrence = cell2mat(tOccurrence);
                classifierScores = cell2mat(classifierScores);
                %passedClassifierTest = cell2mat(passedClassifierTest);
                passedPrecisionTest = cell2mat(passedPrecisionTest);
                isGood = cell2mat(isGood);
                if doDebug
                    classifierLabels = vertcat(classifierLabels{:});
                    peakSNR = cell2mat(peakSNR);
                    clickRanges = cell2mat(clickRanges);
                    x = cell2mat(x);
                end
        
            % Proccess AllIPIs input
            elseif strcmp(inputType,'AllIPIs')
                allIPIs = inputData.IPI;
                tOccurrence = inputData.tOccurred;
                classifierScores = inputData.ClassifierScore;
                passedPrecisionTest = inputData.IsPrecise;
                isGood = classifierScores >= minGoodProb & passedPrecisionTest;
                try
                    tRangeTotal = [tOccurrence(1),tOccurrence(end)];
                catch
                    % no IPIs
                    tRangeTotal = [0,0];
                end
                monitor.setFileClicksFound(numel(allIPIs));
                if doDebug
                    doDebug = false;
                    warning('Option "doDebug" not supported for table input')
                end
            end

            % save AllIPI data
            if doAllIPIs
                IPIData.AllIPIs = table(allIPIs,tOccurrence,classifierScores,passedPrecisionTest,...
                    'VariableNames',{'IPI','tOccurred','ClassifierScore','IsPrecise'});
                if doDebug
                    IPIData.AllIPIs = [...
                        IPIData.AllIPIs,...
                        table(classifierLabels,peakSNR,clickRanges(:,1),clickRanges(:,2),...
                            'VariableNames',{'ClassifierLabel','PeakSNR','ClickStart','ClickEnd'})];
                        
                    % add waveform
                    IPIData.x = x;
                end
            end

            % check if this is the end
            if ~(doFilteredIPIs || doClusters)
                monitor.setMessage('Complete');
                return
            end

            % 9) Do repetition check
            monitor.setMessage('Checking IPIs for repetition');
            goodIPIs = allIPIs(isGood);
            tGood = tOccurrence(isGood);
            isRepeated = CABLE.Routine.checkRepetition(goodIPIs,tGood,tRangeTotal,nIPIReps,ICIRange,ICITol,IPITol);

            % compile final IPIs
            filteredIPIs = goodIPIs(isRepeated);
            filteredIPIOccurrence = tGood(isRepeated);
            monitor.setFileClicksPassed(numel(filteredIPIs));
        
        % Process FilteredIPIs input
        case 'FilteredIPIs'
            filteredIPIs = inputData.IPI;
            filteredIPIOccurrence = inputData.tOccurred;
            monitor.setFileClicksPassed(numel(filteredIPIs));
            
        % Process unsupported cases
        otherwise
            error('CABLE:Routine:main:BadInput',...
                'Input type is not supported')
    end
    
    % save FilteredIPI data
    if doFilteredIPIs
        IPIData.FilteredIPIs = table(filteredIPIs,filteredIPIOccurrence,...
            'VariableNames',{'IPI','tOccurred'});
    end
        
    % check if this is the end
    if ~doClusters
        monitor.setMessage('Complete');
        return
    end
    
    % 10) Cluster IPIs
    monitor.setMessage('Clustering IPIs')
    [GMMs,deltaBICs,clusterMsg] = CABLE.Routine.clusterIPIs(filteredIPIs,Fs,KDEBandwidths,nkExtra,...
        shareSigma,sigma2RegVal,EMTol,maxEMIterations,maxEMTries);

    % save cluster data
    IPIData.Clusters = struct('GMMs',{GMMs},'deltaBICs',{deltaBICs},'message',{clusterMsg});
    
    monitor.setMessage('Complete');
end

%% findInputType ----------------------------------------------------------
function [inputType,inputData] = findInputType(inputFiles)
% Determines input type. Possibilities are "AudioFile", "AudioArray", 
% "AllIPIs", "FilteredIPIs", "Clicks", or "Unsupported".
%   AudioFile: input contains path to an audio file
%   AudioArray: input is an array of paths to multiple audio files
%   AllIPIs: input containes path to one 'AllIPIs' table
%   FilteredIPIs: input containes path to one 'FilteredIPIs' table
%   Clicks: this is a compatibility option for my old OOP implementation. 
%       Input contains path to a MAT file containing an AudioRecording
%       object, which holds Waveform and Clicks objects. No class checking 
%       is done, so it is possible to exploit this option in other ways
%       (e.g. using structs).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % iniialize vector of type checking functions
    checkingFcns = {...
        @checkInput_Audio;...
        @checkInput_Table;...
        @checkInput_Clicks};
    nFcns = numel(checkingFcns);
    
    % Search for types until one is found (or not)
    for ii = 1:nFcns
        fcnii = checkingFcns{ii};
        [typeFound,inputType,inputData] = feval(fcnii,inputFiles);
        if typeFound
            break
        end
    end
    
    % return Unsupported if nothing was found
    if ~typeFound
        inputType = 'Unsupported';
        inputData = [];
    end
    
    % NESTED FUNCTIONS ----------------------------------------------------
    % checkInput_Audio ....................................................
    function [typeFound,inputType,inputData] = checkInput_Audio(inputFiles)
        nFiles = numel(inputFiles);
        try
            for iin = 1:nFiles
                audioinfo(inputFiles{iin});
            end
            if nFiles == 1
                inputType = 'AudioFile';
            else
                inputType = 'AudioArray';
            end
            inputData = [];
            typeFound = true;
        catch
            typeFound = false;
            inputType = '';
            inputData = [];
        end
    end

    % checkInput_Table ....................................................
    function [typeFound,inputType,inputData] = checkInput_Table(inputFiles)
        nFiles = numel(inputFiles);
        try
            assert(nFiles == 1)
            fTable = readtable(inputFiles{:});
            tableFields_Input = fTable.Properties.VariableNames;
            tableFields_AllIPIs = {'IPI','tOccurred','ClassifierScore','IsPrecise'};
            tableFields_FilteredIPIs = {'IPI','tOccurred'};
            if numel(tableFields_Input) == numel(tableFields_AllIPIs) && all(strcmp(tableFields_Input,tableFields_AllIPIs))
                inputType = 'AllIPIs';
                inputData = fTable;
            elseif numel(tableFields_Input) == numel(tableFields_FilteredIPIs) && all(strcmp(tableFields_Input,tableFields_FilteredIPIs))
                inputType = 'FilteredIPIs';
                inputData = fTable;
            else
                error('Unrecognized table fields')
            end
            typeFound = true;
        catch
            typeFound = false;
            inputType = '';
            inputData = [];
        end
    end

    % checkInput_Clicks ...................................................
    function [typeFound,inputType,inputData] = checkInput_Clicks(inputFiles)
        nFiles = numel(inputFiles);
        try
            assert(nFiles == 1)
            load(inputFiles{:},'rec')
            inputData = struct(...
                'x',rec.waveform.x(:,2),...
                'xEnv',rec.waveform.xEnv(:,2),...
                'Fs',rec.Fs,...
                'clickRanges',rec.waveform.clicks.sampleRange,...
                'noise',rec.waveform.clicks.detectionData.noise);
            inputType = 'Clicks';
            typeFound = true;
        catch ME
            typeFound = false;
            inputType = '';
            inputData = [];
        end
    end
end

%% createNoiseFilter ------------------------------------------------------
function [noiseFilter,freqBand] = createNoiseFilter(Fs)
% Returns a Signal Processing Toolbox "digitalFilter" object to be used for
% noise filtration. Parameters are hard-coded, because these are what were
% used to train the click classifier. As a consequence, other values might
% result in lower performance.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % define filter parameters
    fType = 'bandpassiir';
    dMethod = 'butter';
    fStop1 = 100;
    fStop2 = 24000;
    fPass1 = 2000;
    fPass2 = 12000;
    cutoffMatch = 'passband';
    
    % create filter object
   noiseFilter = designfilt(fType,'DesignMethod',dMethod,'MatchExactly',cutoffMatch,'SampleRate',Fs,...
       'StopbandFrequency1',fStop1,'StopbandFrequency2',fStop2,'PassbandFrequency1',fPass1,'PassbandFrequency2',fPass2);
   
   % save frequency bandwidth
   freqBand = [fPass1,fPass2];
end

%% getClickWavSegment -----------------------------------------------------
function [xSub,xEnvSub,pageNoiseSub,clickRangesSub] = getClickWavSegments(x,xEnv,pageNoise,clickRanges)
% Returns segments of a waveform around each click. These are to be used
% for click processing, rather than the whole waveform.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DEV NOTES: This exists because the pulse detector currently has an
% undesirable dependence on waveform segments. Eventually I hope to get rid
% of this dependence and just hard-code a universal buffer.

    % initialize variables
    nClicks = size(clickRanges,2);
    nMin = 1;
    nMax = numel(x);
    xSub = cell(nClicks,1);
    xEnvSub = cell(nClicks,1);
    pageNoiseSub = cell(nClicks,1);
    clickRangesSub = zeros(2,nClicks);
    % end variable initializations
    
    for ii = 1:nClicks
        % loop variables
        clickRangeii = clickRanges(:,ii);
        nClickSamplesii = diff(clickRangeii) + 1;
        bufferii = floor(nClickSamplesii/2);
        indicesii = (clickRangeii(1) - bufferii):(clickRangeii(2) + bufferii);
        nSubSamplesii = numel(indicesii);
        xSubii = zeros(nSubSamplesii,1);
        xEnvSubii = zeros(nSubSamplesii,1);
        pageNoiseSubii = zeros(nSubSamplesii,1);
        
        % index the data vectors where possible. Where it's not possible,
        % the segment will be zero.
        validIndicesii = (indicesii >= nMin) & (indicesii <= nMax);
        clickRangeSubii = clickRangeii - clickRangeii(1) + bufferii + 1;
        xSubii(validIndicesii) = x(indicesii(validIndicesii));
        xEnvSubii(validIndicesii) = xEnv(indicesii(validIndicesii));
        pageNoiseSubii(validIndicesii) = pageNoise(indicesii(validIndicesii));
        
        % save segments to containers
        xSub{ii} = xSubii;
        xEnvSub{ii} = xEnvSubii;
        pageNoiseSub{ii} = pageNoiseSubii;
        clickRangesSub(:,ii) = clickRangeSubii;
    end
end

%% getNFFT ----------------------------------------------------------------
function nfft = getNFFT(clickRanges,nTukeyFalloff,Fs,IPIRange)
% Chooses the optimal number of points to use in Fast Fourier Transform,
% given maximum click duration and IPI being examined.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    maxClickLength = max(diff(clickRanges,[],1) + 1);
    minNFFT_freq = maxClickLength + 2*nTukeyFalloff;
    minNFFT_quef = (2*Fs*IPIRange(2))/1000;
    nfft = 2^nextpow2(max([minNFFT_freq,minNFFT_quef]));
end

%% getPeakSNR -------------------------------------------------------------
function psnr = getPeakSNR(xEnv,pageNoise,clickRange)
% Returns linear peak SNR for one click. It is computed the same as in the 
% feature vector (except it is linear instead of dB). 
% Only used for debug mode.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    clickSamples = clickRange(1):clickRange(2);
    clickEnv = xEnv(clickSamples);
    clickPowNoise = pageNoise(clickSamples);
    [clickEnvPeak,ipeak] = max(clickEnv);
    clickPowSignalPeak = clickEnvPeak^2;
    clickPowNoisePeak = clickPowNoise(ipeak);
    psnr = clickPowSignalPeak./clickPowNoisePeak;   
end