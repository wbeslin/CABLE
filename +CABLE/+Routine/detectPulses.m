%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "detectPulses"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       Signal Processing Toolbox
%       Curve Fitting Toolbox
%
%   Description:
%       Detects the ranges of individual pulses within a sperm whale click.
%       This works by smoothing the click envelope, and then finding peaks
%       in that envelope. This algorithm is rather experimental.
%
%   Input:
%       xEnv [n-by-1 double]:
%           Vector of waveform envelope amplitudes
%       Fs [1-by-1 double]:
%           Sampling rate, in Hertz
%       clickRange [2-by-1 double]:
%           Start and end samples of the click
%       minPulseDuration [1-by-1 double]:
%           Minimum expected duration of individual pulses within sperm
%           whale clicks, in milliseconds
%       maxPulseDuration [1-by-1 double]:
%           Maximum expected duration of individual pulses within sperm
%           whale clicks, in milliseconds
%       minPulseSep [1-by-1 double]:
%           Minimum expected separation between pulses, in milliseconds
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
%       minPromThresh [1-by-1 double]:
%           Threshold determining the minimum prominence that a peak may
%           have to be considered as a signal
%       
%   Output:
%       pulseRanges [2-by-n double]:
%           Matrix of start and end samples for each pulse
%       
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DEV NOTES:
% - For performance reasons, "xEnv" and "clickRange" should be snippets of
%   the full waveform, not the full waveform itself. This will make the
%   output "pulseRanges" return RELATIVE sample indicies.
% - This function inadvertantly ended up with a dependency on the size of
%   the buffer around the click. This is because peaks outside the click
%   are involved in envelope smoothing. This isn't a critical logic error, 
%   but it is undesirable. Eventually I hope to get rid of this dependency,
%   but it may require the determination of new defaults (particularly for 
%   parameters nSmoothRuns, smoothBandwidths, and/or promThreshScale).

function pulseRanges = detectPulses(xEnv,Fs,clickRange,...
        minPulseDuration,maxPulseDuration,minPulseSep,smoothBandwidths,nSmoothRuns,peakBaseHeightProp,promThreshProp,minPromThresh)
    
    % INITIALIZE VARIABLES
    clickSamples = clickRange(1):clickRange(2);
    
    %%% convert milliseconds to samples
    minPulseSamples = ms2samples(minPulseDuration,Fs);
    maxPulseSamples = ms2samples(maxPulseDuration,Fs);
    minPulseSepSamples = ms2samples(minPulseSep,Fs);
    smoothBandwidthsSamples = ms2samples(smoothBandwidths,Fs);
    
    minPeakSepSamples = minPulseSepSamples+minPulseSamples;
    
    % END VARIABLE INITIALIZATIONS
    
    % 1) Smooth the envelope
    [xEnvSmoothed,xPeaks,iPeaks] = smoothClickEnvelope(...
        xEnv,clickSamples,smoothBandwidthsSamples,nSmoothRuns,minPeakSepSamples,minPromThresh);
    
    % 2) Detect peaks. 
    % Determine peak prominence threshold, and recalculate peaks if needed.
    promThresh = determinePromThresh(xPeaks,promThreshProp,minPromThresh);
    if promThresh > minPromThresh
        [~,iPeaks] = findpeaks(xEnvSmoothed,'minPeakProminence',promThresh);
    end
    iPeaks = iPeaks(iPeaks >= clickRange(1) & iPeaks <= clickRange(2));
    xPeaks = xEnvSmoothed(iPeaks);
    nPeaks = numel(xPeaks);
    
    % 3) Abort if there are no peaks
    if nPeaks == 0
        pulseRanges = double.empty(2,0);
        return
    end
    
    % 4) Find pulse ranges
    iPeakBases = getPeakBases(xEnvSmoothed,iPeaks,promThresh);
    pulseRanges = getPulseRanges(xEnvSmoothed,clickRange,iPeaks,iPeakBases,peakBaseHeightProp,minPulseSamples,maxPulseSamples);
    
    % DEBUG
    %{
    if dbplot
        ymax = max(xEnv).*1.1;
        nPulses = size(pulseRanges,2);
        fcolClickPatch = [0.9,0.7,0.8];
        ecolClickPatch = [0.8,0.5,0.7];
        fcolPulsePatch = [0.75,0.95,0.94];
        ecolPulsePatch = [0.49,0.89,0.89];
        xClickPatch = [repelem(clickRange(1),2,1);repelem(clickRange(2),2,1)];
        yClickPatch = [0;ymax;ymax;0];
        xPulsePatch = zeros(4,nPulses);
        yPulsePatch = zeros(4,nPulses);
        for ii = 1:nPulses
            xPulsePatch(:,ii) = [repelem(pulseRanges(1,ii),2,1);repelem(pulseRanges(2,ii),2,1)];
            yPulsePatch(:,ii) = yClickPatch;
        end
        figure
        ha = axes;
        ha.NextPlot = 'add';
        patch(xClickPatch,yClickPatch,fcolClickPatch,'EdgeColor',ecolClickPatch,'LineStyle',':','LineWidth',1.5);
        patch(xPulsePatch,yPulsePatch,fcolPulsePatch,'EdgeColor',ecolPulsePatch,'LineStyle',':','LineWidth',1.5);
        plot(xEnv)
        plot(xEnvSmoothed)
        xlim([1,numel(xEnv)])
        ylim([0,ymax])
    end
    %}
end

%% smoothClickEnvelope ----------------------------------------------------
function [xEnvSmoothed,xPeaks,iPeaks] = smoothClickEnvelope(...
    xEnv,clickSamples,smoothBandwidthsSamples,nSmoothRuns,minPeakSepSamples,minPromThresh)
% Smooths the envelope of a click
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DEV NOTES:
% A buffer beyond the click range should be used. This is not vital for the
% code to work, but not having it may result in poor smoothing near the 
% edges. Even simple zero padding is much better than nothing, but the best
% approach is to use the real waveform around the click. However, using the
% full waveform slows things down considerably. Therefore, "x" and "xEnv"
% here should be snippets of the full waveform, centered about the target
% click. 

    % INITIALIZE VARIABLES
    iBandwidthStart = 1;
    iBandwidthii = iBandwidthStart;
    nBandwidths = numel(smoothBandwidthsSamples);
    xClickPeak = max(xEnv(clickSamples));
    doSmooth = true;
    
    % Smooth the envelope. Do this repeatedly until there are few enough 
    % peaks in the click that they may correspond to actual pulses.
    while doSmooth
        % set smoothing bandwidth and run filter
        bandwidthii = smoothBandwidthsSamples(iBandwidthii);
        xEnvSmoothed = applySmoothingFilter(xEnv,bandwidthii,nSmoothRuns);
        
        % scale the envelope
        envScale = xClickPeak/max(xEnvSmoothed);
        xEnvSmoothed = xEnvSmoothed*envScale;
        
        % Calculate peaks. If any occur within minPeakSep, rerun smoothing 
        % with the next largest window (unless maximum is reached).
        [xPeaks,iPeaks] = findpeaks(xEnvSmoothed,'minPeakProminence',minPromThresh);
        %%% NOTE: Eventually I'd like to enforce the following lines. But 
        %%% this may require new parameter values. See DEV NOTES.
        %iPeaks = iPeaks(iPeaks >= clickSamples(1) & iPeaks <= clickSamples(end));
        %xPeaks = xEnvSmoothed(iPeaks);
        peakSepSamples = diff(iPeaks);
        if any(peakSepSamples < minPeakSepSamples) && (iBandwidthii < nBandwidths)
            iBandwidthii = iBandwidthii + 1;
        else
            doSmooth = false;
        end
    end
end

%% determinePromThresh ----------------------------------------------------
function promThresh = determinePromThresh(xPeaks,promThreshProp,minPromThresh)
% Determines the prominence threshold to use for finding peaks in the
% smoothed envelope. This threshold is determined based on the range of
% existing peak prominences.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % get maximum difference in peak heigths
    xPeakDiffMax = max(xPeaks) - min(xPeaks);
    
    % determine prominence threshold based on proportion of max peak
    % difference and threshold floor
    promThresh = xPeakDiffMax*promThreshProp;
    if isempty(promThresh) || (promThresh < minPromThresh) 
        promThresh = minPromThresh;
    end
end

%% getPeakBases -----------------------------------------------------------
function iPeakBases = getPeakBases(xEnv,iPeaks,promThresh)
% Returns the values and locations of the bases for each peak. Bases are
% the troughs or endpoints surrounding each peak.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Find troughs which should correspond to the peak bases
    [~,iTroughs] = findpeaks(-xEnv+max(xEnv),'minPeakProminence',promThresh);
    
    % append endpoints
    iBaseVecAll = unique([1;iTroughs;numel(xEnv)]);
    
    % keep only the first points that extend beyond the peak indices (i.e.,
    % constrain between the first point to the left of the first peak, and
    % the first point to the right of the last peak)
    leftBound = find(iBaseVecAll < iPeaks(1),1,'last');
    rightBound = find(iBaseVecAll > iPeaks(end),1,'first');
    iBaseVec = iBaseVecAll(leftBound:rightBound);
    
    % create index vectors for left and right bases
    iBasesLeft = iBaseVec(1:(end-1));
    iBasesRight = iBaseVec(2:end);
    
    % create peak base index matrix
    iPeakBases = [iBasesLeft,iBasesRight];
end

%% getPulseRanges ---------------------------------------------------------
function pulseRanges = getPulseRanges(xEnv,clickRange,iPeaks,iPeakBases,heightPropInitial,minPulseSamples,maxPulseSamples)
% Returns sample ranges of pulses. Ranges are found by measuring the points
% about each peak where the envelope crosses some reference height. The
% reference height is dependent on the bases of each peak. Pulses that are
% too short are removed, and those that are too long are reduced (if 
% possible) 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % INITIALIZE VARIABLES
    nPeaks = numel(iPeaks);
    heightStep = 0.01; % arbitrary number for increasing peak-base reference height if pulse is too wide
    pulseRanges = zeros(2,nPeaks);
    % END VARIABLE INITIALIZATION
    
    % loop through each pulse
    ii = 1;
    while ii <= nPeaks
        %fprintf('   PROCESSING PULSE %d/%d\n',ii,nPeaks)
        iPeakii = iPeaks(ii);
        xEnvPeakii = xEnv(iPeakii);
        iPeakBasesii = iPeakBases(ii,:);
        searchSamplesii = (iPeakBasesii(1):iPeakBasesii(2))';
        heightProp = heightPropInitial;
        rangeFound = false;
        removePulse = false;
        
        % find range
        while ~rangeFound && ~removePulse
            %disp('   evaluating range')
            % get reference amplitudes
            peakBaseDiffsii = xEnvPeakii - xEnv(iPeakBasesii);
            xInterceptsii = xEnvPeakii - peakBaseDiffsii*heightProp;
            
            % find where the envelope crosses the intercept points within
            % the peak bases
            pulseRangesii = CABLE.Routine.peakExtents(searchSamplesii,xEnv(searchSamplesii),iPeakii,xInterceptsii,false);
            pulseRangesii = pulseRangesii';
            
            % constrain to click range
            pulseRangesii(pulseRangesii < clickRange(1)) = clickRange(1);
            pulseRangesii(pulseRangesii > clickRange(2)) = clickRange(2);
             
            % evaluate width
            pulseWidthii = diff(pulseRangesii) + 1;
            if pulseWidthii < minPulseSamples
                %disp('   Pulse too short - removing')
                % remove pulse
                removePulse = true;
            elseif pulseWidthii > maxPulseSamples
                %disp('   Pulse too large - shrinking...')
                % try increasing the reference amplitude. If it's not
                % possible, remove pulse.
                heightProp = heightProp - heightStep;
                %fprintf('heightProp = %.3g\n',heightProp)
                if heightProp <= 0
                    %disp('   Shrink failed - removing')
                    removePulse = true;
                end
            else
                %disp('   Range found - moving on to next pulse')
                % keep pulse, save its data, and move to next
                rangeFound = true;
                pulseRanges(:,ii) = pulseRangesii;
                ii = ii + 1;
                continue
            end
            
            if removePulse
                iPeaks(ii) = [];
                iPeakBases(ii,:) = [];
                nPeaks = numel(iPeaks);
            end
        end
    end
    
    % remove unused container space
    pulseRanges = pulseRanges(:,all(pulseRanges>0,1));
end

%% ms2samples -------------------------------------------------------------
function sampDur = ms2samples(msDur,Fs)
% converts time in milliseconds to samples
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% DEV NOTES: thinking of making this a more general utility function

    sampDur = round(Fs*(msDur/1000));
end

%% applySmoothingFilter ---------------------------------------------------
function x = applySmoothingFilter(x,bandwidth,nRuns)
% Smooths an input vector "x" using the LOWESS method.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    for ii = 1:nRuns
        x = smooth(x,bandwidth,'lowess'); % Curve Fitting Toolbox function
    end
end