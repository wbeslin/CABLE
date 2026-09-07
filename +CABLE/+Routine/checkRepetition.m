%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "checkRepetition"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       none
%
%   Description:
%       Checks IPIs for successive repetition in the time series. 
%
%   Input:
%       IPIs [n-by-1 double]:
%           Vector of click IPIs, in milliseconds
%       tOccurrence [n-by-1 double]:
%           Vector of click occurrence times, in seconds
%       tRange [1-by-2 double]:
%           Start and end times of the full recording, in seconds
%       nIPIReps [1-by-1 double]:
%           The number of local IPI repetitions needed for an IPI to be
%           considered valid. One repetition means that there exist two 
%           instances of an IPI within ICI range.
%       ICIRange [1-by-2 double]:
%           The minimum and maximum inter-click interval (ICI) limits 
%       ICITol [1-by-1 double]:
%           The maximum expected difference in ICI between successive
%           clicks in a click train, in seconds. This is used only when 
%           checking for 2 or more IPI repetitions. After the first 
%           repetition is found within the range specified by "ICIRange", 
%           later repetition checks adjust the range based on "ICITol". The 
%           result is that only similar ICIs are considered when analyzing 
%           the same train.
%       IPITol [1-by-1 double]:
%           The maximum expected difference in IPI between successive
%           clicks in a click train, in milliseconds.
%
%   Output:
%       repeated [n-by-1 logical]: 
%           Vector specifying if each IPI was found repeated in a train or 
%           not
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function repeated = checkRepetition(IPIs,tOccurrence,tRange,nIPIReps,ICIRange,ICITol,IPITol)

    % do forward scan
    clicksToCheck = true(size(IPIs));
    repeated = scan4rep(clicksToCheck,true);
    
    % do backwards scan
    clicksToCheck = ~repeated;
    repeated = scan4rep(clicksToCheck,false);

    %% NESTED FUNCTIONS ---------------------------------------------------
    function repeated = scan4rep(clicksToCheck,forwardDirection)

        % INITIALIZE VARIABLES
        if forwardDirection
            iClicksToCheck = find(clicksToCheck);
            tMax = tRange(2);
        else
            iClicksToCheck = flip(find(clicksToCheck));
            tOccurrence = -tOccurrence;
            tMax = tRange(1);
        end
        repeated = ~clicksToCheck;
        iUncheckedClicks = iClicksToCheck;
        % END VARIABLE INITIALIZATION

        % Begin outer repetition check loop
        while ~isempty(iUncheckedClicks)
            iFocalClick = iUncheckedClicks(1);
            iIPIsInAllRanges = cell(nIPIReps,1);
            iClick = iFocalClick;
            %iclickOld = iClick; % FOR DEBUGGING ONLY.
            repCount = 0;
            scanUnsuccessful = false;

            % Begin internal repetition loop. Note that this won't
            % execute if no repetitions are needed.
            while ~scanUnsuccessful && repCount < nIPIReps

                % define scan range in the occurence time axis, and
                % check if it's within bounds.
                % - If minimum is out, abort.
                % - If maximum is out, trim it down.
                if repCount == 0
                    ICIScanRange = tOccurrence(iClick) + ICIRange;
                else
                    ICIScanRange = tOccurrence(iClick) + [currentICI-ICITol,currentICI+ICITol];
                end
                if ICIScanRange(1) > tMax
                    %dbmsg(verbose,'        proximal limit out of bounds; terminating scan')
                    scanUnsuccessful = true;
                    %if ~dodebug
                    %    break
                    %end
                elseif ICIScanRange(2) > tMax
                    %dbmsg(verbose,'        distal limit out of bounds; reducing range')
                    ICIScanRange(2) = tMax;
                end
                % make sure range does not overlap with current
                % click
                if ICIScanRange(1) <= tOccurrence(iClick)
                    %dbmsg(verbose,'        proximal limit overlaps with current click; reducing range')
                    ICIScanRange(1) = tOccurrence(iClick+1);
                end

                % define scan range in the IPI axis
                IPIScanRange = [IPIs(iClick)-IPITol, IPIs(iClick)+IPITol];

                % look for IPIs within scanning region
                IPIsInRange =...
                    tOccurrence >= ICIScanRange(1) &...
                    tOccurrence <= ICIScanRange(2) &...
                    IPIs >= IPIScanRange(1) &...
                    IPIs <= IPIScanRange(2);

                % if no IPIs were found, try checking the next
                % click in the current repetition level. 
                % - If there aren't any, go down one level and
                % search the next click in that range. 
                % - If there are no more levels to go down to,
                % terminate the scan.
                if ~any(IPIsInRange)
                    %dbmsg(verbose,'        no IPI repetitions found; searching next click in range')
                    changingClicks = true;
                    while changingClicks
                        try
                            iIPIsInAllRanges{repCount}(1) = []; % remove iclick from previous range
                            try
                                iClick = iIPIsInAllRanges{repCount}(1); % go to next click in previous range
                                % edit ICI if needed
                                if repCount == 1
                                    currentICI = abs(diff([tOccurrence(iFocalClick),tOccurrence(iClick)]));
                                end
                                changingClicks = false;
                            catch % no more clicks in previous range; decrement repetition count and restart at previous level
                                %dbmsg(verbose,'        no more clicks; searching in previous repetition range')
                                repCount = repCount - 1;
                            end
                        catch % no more ranges to check
                            %dbmsg(verbose,'        no more ranges; terminating scan')
                            scanUnsuccessful = true;
                            changingClicks = false;
                        end
                    end
                else
                % If IPIs were found, add them to the list of IPIs
                % within the next range level.
                    %dbmsg(verbose,'        IPI repetitions found!')
                    iIPIsInRange = find(IPIsInRange);
                    if ~forwardDirection
                        iIPIsInRange = flip(iIPIsInRange);
                    end
                    iIPIsInAllRanges{repCount+1} = iIPIsInRange;
                    %iclickOld = iClick; % FOR DEBUGGING ONLY.
                    iClick = iIPIsInRange(1);
                    if repCount == 0
                        currentICI = abs(diff([tOccurrence(iFocalClick),tOccurrence(iClick)]));
                    end
                    repCount = repCount + 1;
                end

                % DEBUG
                %{
                if dodebug
                    if forwardDirection
                        tclicksPlot = tOccurrence;
                        ICIscanRangePlot = ICIScanRange;
                        linst = '-';
                    else
                        tclicksPlot = -tOccurrence;
                        ICIscanRangePlot = -ICIScanRange;
                        linst = '--';
                    end
                    if ~any(IPIsInRange)
                        pcol = [1,0,0];
                    else
                        pcol = [0,1,0];
                    end

                    % all IPIs (good before repetition)
                    plot(tclicksPlot(clicksToCheck),IPIs(clicksToCheck),'.')
                    hold on
                    % current IPI
                    plot(tclicksPlot(iclickOld),IPIs(iclickOld),'o')
                    % range patch
                    xpatch = [ICIscanRangePlot(1),ICIscanRangePlot(1),ICIscanRangePlot(2),ICIscanRangePlot(2)];
                    ypatch = [IPIScanRange(1),IPIScanRange(2),IPIScanRange(2),IPIScanRange(1)];
                    patch(xpatch,ypatch,pcol,'FaceAlpha',0.2,'LineStyle',linst);
                    % IPIs in range
                    plot(tclicksPlot(IPIsInRange),IPIs(IPIsInRange),'o')
                    % selected IPI
                    plot(tclicksPlot(iClick),IPIs(iClick),'+')
                    xlabel('time (s)')
                    ylabel('IPI (ms)')
                    if iclickOld == iFocalClick
                        xlim(tclicksPlot(iclickOld)+[-8,8])
                        ylim(IPIs(iclickOld)+2.5*[-IPITol,IPITol])
                    end
                    disp('run complete')
                    keyboard
                end
                % END DEBUG
                %}
            end

            % process results of repetition check run:
            % If repetitions were found, mark all involved clicks 
            % as good and add them to the list of checked clicks. 
            % Otherwise, only the current click gets added to the 
            % list (but it's not counted as "good").
            if scanUnsuccessful
                %dbmsg(verbose,'    CLICK REJECTED')
                iicheckedClicks = 1;
            else
                %dbmsg(verbose,'    CLICKS ACCEPTED!')
                iRepeatedInstances = zeros(nIPIReps+1,1);
                iRepeatedInstances(1) = iFocalClick;
                for ii = 1:nIPIReps
                    iRepeatedInstances(ii+1) = iIPIsInAllRanges{ii}(1);
                end
                repeated(iRepeatedInstances) = true;
                [~,~,iicheckedClicks] = intersect(iRepeatedInstances,iUncheckedClicks);
            end
            iUncheckedClicks(iicheckedClicks) = [];
        end
    end
end