% function for running CABLE from the command line (no GUI).
% File merging not supported. Specify strings for each input and output
% file path. Output paths may also be empty.
% Advanced parameters use default values.
%
% Dependencies: Custom (uninterpretedString)
%
% May 2018

function varargout = CABLE_Console(inputFilePaths,outputFilePaths,...
    nIPIReps,minGoodProb,doDebug,doAllIPIs,doFilteredIPIs,doClusters)
    % PART 1) INITIALIZATION ----------------------------------------------
    
    % parse input
    p = inputParser;
    
    %%% verbose
    validVerbose = @(arg) validateattributes(arg,{'logical'},{'scalar'});
    defaultVerbose = true;
    p.addParameter('verbose',defaultVerbose,validVerbose)
    
    % input
    nFiles = numel(inputFilePaths);
    
    % output
    nargoutchk(0,1)
    %varargout = {};
    if nargout > 0
        IPIDataAll = struct();
        returnOutput = true;
    else
        returnOutput = false;
    end
    if isempty(outputFilePaths)
        saveOutput = false;
    else
        saveOutput = true;
    end
    if ~returnOutput && ~saveOutput
        warning('No output!')
        return
    end
    
    % set classifier file path
    rootDir = fileparts(mfilename('fullpath'));
    classFileName = 'ClickClassifier.mat';
    classFile = fullfile(rootDir,classFileName);

    % create monitor object
    monitor = IPICompiler.StatusMonitor_Console();

    % create parallel cluster object
    parClust = parcluster;

    % set parameter values
    nCores = max(parClust.NumWorkers);
    %doDebug = true;
    %doAllIPIs = false;
    %doFilteredIPIs = true;
    %doClusters = true;
    splitDuration = IPICompiler.InputParameterManager.builtInDefaults.recSplitDuration;
    minDuration = IPICompiler.InputParameterManager.builtInDefaults.minSegmentDuration;
    channelIndex = IPICompiler.InputParameterManager.builtInDefaults.channelIndex;
    threshOn = IPICompiler.InputParameterManager.builtInDefaults.threshOn;
    threshOff = IPICompiler.InputParameterManager.builtInDefaults.threshOff;
    alphaSignal = IPICompiler.InputParameterManager.builtInDefaults.alphaSignal;
    alphaNoiseOn = IPICompiler.InputParameterManager.builtInDefaults.alphaNoiseOn;
    alphaNoiseOff = IPICompiler.InputParameterManager.builtInDefaults.alphaNoiseOff;
    minEchoProp = IPICompiler.InputParameterManager.builtInDefaults.minEchoProp;
    IPIRange = IPICompiler.InputParameterManager.builtInDefaults.IPIRange;
    maxClickDuration = IPICompiler.InputParameterManager.builtInDefaults.maxClickDuration;
    minClickSep = IPICompiler.InputParameterManager.builtInDefaults.minClickSep;
    tTukeyFalloff = IPICompiler.InputParameterManager.builtInDefaults.tukeyFalloffDuration;
    minPulseDuration = IPICompiler.InputParameterManager.builtInDefaults.pulseDurationRange(1);
    maxPulseDuration = IPICompiler.InputParameterManager.builtInDefaults.pulseDurationRange(2);
    smoothBandwidths = IPICompiler.InputParameterManager.builtInDefaults.smoothBandwidths;
    nSmoothRuns = IPICompiler.InputParameterManager.builtInDefaults.nSmoothRuns;
    peakBaseHeightProp = IPICompiler.InputParameterManager.builtInDefaults.peakBaseHeightProp;
    promThreshProp = IPICompiler.InputParameterManager.builtInDefaults.promThreshProp;
    minPromThreshScale = IPICompiler.InputParameterManager.builtInDefaults.minPromThreshScale;
    %minGoodProb = IPICompiler.InputParameterManager.builtInDefaults.minGoodProb;
    maxIPIDeviation = IPICompiler.InputParameterManager.builtInDefaults.maxIPIDeviation;
    doIPIMethod = struct(...
        'Autocorrelation',IPICompiler.InputParameterManager.builtInDefaults.doMethod_Autocorrelation,...
        'Cepstrum',IPICompiler.InputParameterManager.builtInDefaults.doMethod_Cepstrum);
    useChiSquared = struct(...
        'Autocorrelation',IPICompiler.InputParameterManager.builtInDefaults.useChiSquared_Autocorrelation,...
        'Cepstrum',IPICompiler.InputParameterManager.builtInDefaults.useChiSquared_Cepstrum);
    %nIPIReps = IPICompiler.InputParameterManager.builtInDefaults.nIPIReps;
    ICIRange = IPICompiler.InputParameterManager.builtInDefaults.ICIRange;
    ICITol = IPICompiler.InputParameterManager.builtInDefaults.ICITol;
    IPITol = IPICompiler.InputParameterManager.builtInDefaults.IPITol;
    KDEBandwidth = IPICompiler.InputParameterManager.builtInDefaults.KDEBandwidths;
    nkExtra = IPICompiler.InputParameterManager.builtInDefaults.nkExtra;
    shareSigma = IPICompiler.InputParameterManager.builtInDefaults.shareSigma;
    GMMTol = IPICompiler.InputParameterManager.builtInDefaults.GMMTol;
    nEMIterMax = IPICompiler.InputParameterManager.builtInDefaults.maxEMIterations;
    nEMTriesMax = IPICompiler.InputParameterManager.builtInDefaults.maxEMTries;

    % open parallel pool
    p = gcp('nocreate');
    if nCores > 1
        if isempty(p)
            % create pool
            parpool(nCores);
        elseif p.NumWorkers ~= nCores
            % reset pool
            delete(gcp)
            parpool(nCores);
        end
    elseif ~isempty(p)
        % shut down pool
        delete(gcp)
    end
    
    % initialize waitbar
    hwb = waitbar(0,sprintf('%s\n\nPlease wait...',repmat(' ',1,150)));
    ettotal = 0;
    
    % PART 2) RUNNING -----------------------------------------------------
    for ii = 1:nFiles
        % initialize loop
        %%% monitor
        monitor.reset();
        %%% input
        inFilePathii = inputFilePaths{ii};
        [~,fileNameii] = fileparts(inFilePathii);
        %%% output
        if saveOutput
            outFilePathii = outputFilePaths{ii};
        end
        %%% waitbar update
        etr = duration(0,0,round((ettotal/(ii-1))*nFiles)-ettotal);
        dtnow = datetime('now');
        edtc = dtnow + etr;
        waitmsg = sprintf('Processing file "%s"\nEstimated time of completion = %s\nTime remaining = %s',uninterpretedString(fileNameii),char(edtc),char(etr));
        waitbar((ii-1)/nFiles,hwb,waitmsg); 
        
        % run
        tic
        try
            % Run IPI compiler (The Magic Line)
            IPIData = IPICompiler.main(...
                'inputFiles',{inFilePathii},...
                'monitor',monitor,...
                'classFile',classFile,...
                'doDebug',doDebug,...
                'doAllIPIs',doAllIPIs,...
                'doFilteredIPIs',doFilteredIPIs,...
                'doClusters',doClusters,...
                'splitDuration',splitDuration,...
                'minDuration',minDuration,...
                'channelIndex',channelIndex,...
                'threshOn',threshOn,...
                'threshOff',threshOff,...
                'alphaSignal',alphaSignal,...
                'alphaNoiseOn',alphaNoiseOn,...
                'alphaNoiseOff',alphaNoiseOff,...
                'minEchoProp',minEchoProp,...
                'IPIRange',IPIRange,...
                'maxClickDuration',maxClickDuration,...
                'minClickSep',minClickSep,...
                'tTukeyFalloff',tTukeyFalloff,...
                'minPulseDuration',minPulseDuration,...
                'maxPulseDuration',maxPulseDuration,...
                'smoothBandwidths',smoothBandwidths,...
                'nSmoothRuns',nSmoothRuns,...
                'peakBaseHeightProp',peakBaseHeightProp,...
                'promThreshProp',promThreshProp,...
                'minPromThreshScale',minPromThreshScale,...
                'minGoodProb',minGoodProb,...
                'maxIPIDeviation',maxIPIDeviation,...
                'doIPIMethod',doIPIMethod,...
                'useChiSquared',useChiSquared,...
                'nReps',nIPIReps,...
                'ICIRange',ICIRange,...
                'ICITol',ICITol,...
                'IPITol',IPITol,...
                'KDEBandwidth',KDEBandwidth,...
                'nkExtra',nkExtra,...
                'shareSigma',shareSigma,...
                'GMMTol',GMMTol,...
                'nEMIterMax',nEMIterMax,...
                'nEMTriesMax',nEMTriesMax);

            % save output
            if saveOutput
                save(outFilePathii,'-struct','IPIData')
            end
            if returnOutput
                IPIDataAll.(fileNameii) = IPIData;
                varargout = {IPIDataAll};
            end
        catch ME
            warning('%s',ME.message)
            if saveOutput
                [outFileDirii,outFileNameii] = fileparts(outFilePathii);
                fID = fopen(fullfile(outFileDirii,[outFileNameii,'.txt']),'w');
                fprintf(fID,'%s',ME.getReport('extended','hyperlinks','off'));
                fclose(fID);
            end
        end
        et = toc;
        ettotal = ettotal + et;
    end
    
    % remove waitbar
    delete(hwb)
end