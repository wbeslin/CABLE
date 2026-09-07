%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "parseAudioInput"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       none
%
%   Description:
%       Examines input audio files and determines how they should be
%       accessed (i.e. when they should be used, and where they should be
%       split apart).
%
%   Input:
%       inputFiles [n-by-1 cell]:
%           Cell array containing one or more strings describing paths to 
%           input files
%       recSplitDuration [1-by-1 double]:
%           Duration at which to split audio files into segments, in
%           minutes
%       minSegmentDuration [1-by-1 double]:
%           Minimum allowed duration of an audio segment, in minutes
%
%   Output:
%       sampleRanges [n-by-2 double]:
%           Matrix of start and end samples for each segment
%       timeRanges [n-by-2 double]:
%           Matrix of start and end times for each segment, in seconds
%       recIndices [n-by-1 double]:
%           Vector containing the source recording number of each segment
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [sampleRanges,timeRanges,recIndices] = parseAudioInput(inputFiles,recSplitDuration,minSegmentDuration)

    % INITIALIZE VARIABLES
    nRecs = numel(inputFiles);
    sampleRanges = cell(nRecs,1);
    timeRanges = cell(nRecs,1);
    recIndices = cell(nRecs,1);
    % END VARIABLE INITIALIZATION
    
    % analyze audio files
    tStart = 0;
    for ii = 1:nRecs
        fileii = inputFiles{ii};
        
        % get file info
        infoii = audioinfo(fileii);
        recSamplesii = infoii.TotalSamples;
        Fsii = infoii.SampleRate;
        
        % get split sample ranges
        splitSampleRangesii = getTruncSampleRanges(recSplitDuration,minSegmentDuration,recSamplesii,Fsii);
        nSplitsii = size(splitSampleRangesii,1);
        
        % get time ranges (in seconds)
        splitTimeRangesii = (splitSampleRangesii - 1)/Fsii + tStart;
        
        % save stuff to containers
        sampleRanges{ii} = splitSampleRangesii;
        timeRanges{ii} = splitTimeRangesii;
        recIndices{ii} = repelem(ii,nSplitsii,1);
        
        % update tStart
        tStart = splitTimeRangesii(end) + 1/Fsii;
    end
    
    % concatenate cells
    sampleRanges = cell2mat(sampleRanges);
    timeRanges = cell2mat(timeRanges);
    recIndices = cell2mat(recIndices);
end

%% getTruncSampleRanges ---------------------------------------------------
function sampleRanges = getTruncSampleRanges(recSplitDuration,minSegmentDuration,nSamples,Fs)
% Outputs the start and end samples at which to break up a file.
% Output is a matrix of size [ntruncs,2]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % determine splitting and minimum sizes in samples
    splitSamples = round(recSplitDuration*60*Fs);
    minSamples = round(minSegmentDuration*60*Fs);
    
    % make sure the recording has more samples than minSamples. If it
    % doesn't, use the the full range.
    if nSamples <= minSamples
        sampleRanges = [1,nSamples];
    else
        % get number of times the splitting size wholly fits into nsamples
        fullSplits = floor(nSamples/splitSamples);
        splitRem = rem(nSamples,splitSamples);
        % if the number of remaining samples is smaller than minimum, last
        % split will be longer; otherwise, add another truncation that
        % will be smaller.
        if splitRem < minSamples;
            nSplits = fullSplits;
        else
            nSplits = fullSplits + 1;
        end

        % create sampleRanges
        sampleRanges = zeros(nSplits,2);
        sampleRanges(:,1) = splitSamples*(0:nSplits-1)+1;
        sampleRanges((1:end-1),2) = splitSamples*(1:nSplits-1);
        sampleRanges(end,2) = nSamples;
    end
end