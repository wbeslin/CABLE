%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Class "StatusMonitor"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies: 
%       none
%
%   Description:
%       Handle class for monitoring the progress of IPI compilation. The
%       routine passes information to an instance of this class as it runs, 
%       which the instance then displays on GUI components. It also has an 
%       "abort" flag, which will cause an error to be thrown when true. 
%       This is used to interrupt execution. The state of "abort" is 
%       checked every time the routine sends information to the 
%       "StatusMonitor" instance.
%
%   Constructor Syntax:
%       obj = StatusMonitor(<Name>,<Value>)
%
%   Name-Value Pairs:
%       These correspond to the handles of each GUI component reserved for 
%       displaying information. They are all required. See the constructor 
%       for the full list.
%       
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

classdef StatusMonitor < handle
    % PROPERTIES ==========================================================
    properties
        abort   % Logical specifying if routine should be interrupted
    end
    properties(Constant)
        % This is a list of recognized routine states, used to control
        % which status elements can be updated when:
        stateList ={...     
            'clean';... % file count undefined
            'file count defined';... % file count defined, durations undefined
            'file durations defined';... % file durations defined, no file started
            'started file';... % new file started, type undefined
            'processing file (unsegmented)';... % unsegmentd file in progress
            'processing file (pre-segment)';... % segmented file in progress, no segments analyzed yet
            'processing file (post-segment)';... % segmented file in progress, all segments analyzed
            'processing segment';... % segment in progress
            'completed segment';... % segment complete, preparing for next
            'completed file';... % file complete, preparing for next
            'finished'};    % routine finished
    end
    properties (SetAccess = private)
        % Graphic object handles
        h_Message
        h_FileName
        h_FileType
        h_FileDuration
        h_SegmentDuration
        h_FileClicksFound
        h_SegmentClicksFound
        h_FileClicksPassed
        h_LaunchTime
        h_CompletionTime
        h_TimeElapsed
        h_TimeRemaining
        h_axesProgress
        h_surfaceFileProgress
        h_surfaceSegmentProgress
    end
    properties (SetAccess = private)
        currentState    % String describing current state, which is one of the "stateList" entries
        messageHeadStr  % String displaying the current file and segment being processed, if any
        nFiles          % Number of files to process
        iFile           % Index of file currently being processed
        nSegments       % Number of segments to process in current file
        iSegment        % Index of segment currently being processed
        nGridSegments   % Number used to divide the progress bar into files/segments
        dtUpdated       % Datetime of last update
        dFiles          % Duration of each file, if applicable
    end
    properties (SetAccess = private, Dependent)
        % These data are stored inside UI components
        messageStr
        fileName
        fileType
        fileDuration
        segmentDuration
        nFileClicksFound
        nSegmentClicksFound
        nFileClicksPassed
        dtLaunch
        dtCompletion
    end
    
    %% METHODS - PUBLIC ===================================================
    methods
        %% Constructor ----------------------------------------------------
        function obj = StatusMonitor(varargin)
        % Creates a StatusMonitor instance.
        % Use Name-Value pairs to set the handles of all graphics objects.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              
            % initialize variables
            validUIControl = @(h) validateattributes(h,{'matlab.ui.control.UIControl'},{'scalar'});
            validAxes = @(h) validateattributes(h,{'matlab.graphics.axis.Axes'},{'scalar'});
            p = inputParser;
            p.CaseSensitive = true;
            p.PartialMatching = false;
            
            % parse input
            p.addParameter('h_Message',[],validUIControl)
            p.addParameter('h_FileName',[],validUIControl)
            p.addParameter('h_FileType',[],validUIControl)
            p.addParameter('h_FileDuration',[],validUIControl)
            p.addParameter('h_SegmentDuration',[],validUIControl)
            p.addParameter('h_FileClicksFound',[],validUIControl)
            p.addParameter('h_SegmentClicksFound',[],validUIControl)
            p.addParameter('h_FileClicksPassed',[],validUIControl)
            p.addParameter('h_LaunchTime',[],validUIControl)
            p.addParameter('h_CompletionTime',[],validUIControl)
            p.addParameter('h_TimeElapsed',[],validUIControl)
            p.addParameter('h_TimeRemaining',[],validUIControl)
            p.addParameter('h_axesProgress',[],validAxes)
            
            p.parse(varargin{:})
            
            % make sure everything was set
            if ~isempty(p.UsingDefaults)
                error('Missing the following inputs:\n%s',strjoin(p.UsingDefaults))
            end
            
            % assign
            obj.h_Message = p.Results.h_Message;
            obj.h_FileName = p.Results.h_FileName;
            obj.h_FileType = p.Results.h_FileType;
            obj.h_FileDuration = p.Results.h_FileDuration;
            obj.h_SegmentDuration = p.Results.h_SegmentDuration;
            obj.h_FileClicksFound = p.Results.h_FileClicksFound;
            obj.h_SegmentClicksFound = p.Results.h_SegmentClicksFound;
            obj.h_FileClicksPassed = p.Results.h_FileClicksPassed;
            obj.h_LaunchTime = p.Results.h_LaunchTime;
            obj.h_CompletionTime = p.Results.h_CompletionTime;
            obj.h_TimeElapsed = p.Results.h_TimeElapsed;
            obj.h_TimeRemaining = p.Results.h_TimeRemaining;
            obj.h_axesProgress = p.Results.h_axesProgress;
            
            % reset everything
            obj.totalReset()
        end
        
        %% set.abort ------------------------------------------------------
        function set.abort(obj,f)
            validateattributes(f,{'logical'},{'scalar'})
            obj.abort = f;
        end
        
        %% totalReset -----------------------------------------------------
        function totalReset(obj)
        % Clears all file and segment information.
        % The only component left untouched is the message.
        % Call this before launching the routine.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.abort = false;
            obj.nFiles = double.empty;
            obj.iFile = double.empty;
            obj.nSegments = double.empty;
            obj.iSegment = double.empty;
            obj.nGridSegments = double.empty;
            obj.dFiles = duration.empty;
            obj.fileName = '<none>';
            obj.fileType = char.empty;
            obj.fileDuration = duration.empty;
            obj.segmentDuration = duration.empty;
            obj.nFileClicksFound = double.empty;
            obj.nSegmentClicksFound = double.empty;
            obj.nFileClicksPassed = double.empty;
            obj.resetTimer()
            obj.updateMessageHead('none')
            obj.updateProgressBar('reset')
            obj.currentState = 'clean';
            
            obj.refresh()
        end
        
        %% startTimer -----------------------------------------------------
        function startTimer(obj)
        % Records the start time.
        % Call this just before launching the routine after reset.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case {'clean','file count defined','file durations defined'}
                    obj.dtLaunch = datetime('now');
                otherwise
                    obj.throwStateError('start timer');
            end
            
            obj.refresh()
        end
        
        %% setFileCount ---------------------------------------------------
        function setFileCount(obj,n)
        % Sets the number of files being analyzed.
        % Call this before running the routine after reset.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case 'clean'
                    obj.nFiles = n;
                    obj.updateProgressBar('initialize')
                    obj.currentState = 'file count defined';
                otherwise
                    obj.throwStateError('set file count')
            end
            
            obj.refresh()
        end
        
        %% setSegmentCount ------------------------------------------------
        function setSegmentCount(obj,n)
        % Sets the number of waveform segments.
        % Call this once an audio file's segments are established.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case 'processing file (pre-segment)'
                    % set nSegments
                    if isempty(obj.nSegments)
                        nSegmentsOld = 0;
                    else
                        nSegmentsOld = obj.nSegments;
                    end
                    obj.nSegments = n;
                    
                    % set nGridSegments
                    if isempty(obj.nGridSegments)
                        obj.nGridSegments = obj.nSegments;
                    else
                        obj.nGridSegments = obj.nGridSegments - nSegmentsOld + n;
                    end
                otherwise
                    obj.throwStateError('set segment count')
            end
            
            obj.refresh()
        end
        
        %% newFile --------------------------------------------------------
        function newFile(obj)
        % Marks the start of a new file.
        % File and segment information is reset.
        % Call this once a new file is being processed.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case {'file durations defined','completed file'}
                    
                    % set iFile
                    if isempty(obj.iFile)
                        obj.iFile = 1;
                    else
                        obj.iFile = obj.iFile + 1;
                    end
                    assert(obj.iFile <= obj.nFiles,'Number of files exceeded')
                    
                    % reset relevant properties
                    obj.nSegments = double.empty;
                    obj.iSegment = double.empty;
                    obj.fileName = char.empty;
                    obj.fileType = char.empty;
                    obj.fileDuration = duration.empty;
                    obj.segmentDuration = duration.empty;
                    obj.nFileClicksFound = double.empty;
                    obj.nSegmentClicksFound = duration.empty;
                    obj.nFileClicksPassed = double.empty;

                    % update message header and progress bar
                    obj.updateMessageHead('file')
                    obj.setMessage('Initializing')
                    
                    % update state
                    obj.currentState = 'started file';

                otherwise
                    obj.throwStateError('start new file')
            end
            
            obj.refresh()
        end
        
        %% newSegment -----------------------------------------------------
        function newSegment(obj)
        % Marks the start of a new segment.
        % Segment information is reset.
        % Call this once a new segment is being processed.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case {'processing file (pre-segment)','completed segment'}
                    
                    % set iSegment
                    assert(~isempty(obj.nSegments),'Number of segments is undefined')
                    if isempty(obj.iSegment)
                        obj.iSegment = 1;
                    else
                        obj.iSegment = obj.iSegment + 1;
                    end
                    assert(obj.iSegment <= obj.nSegments,'Number of segments exceeded')
                    
                    % reset relevant properties
                    obj.segmentDuration = duration.empty;
                    obj.nSegmentClicksFound = double.empty;

                    % update message header and progress bar
                    obj.updateMessageHead('segment')
                    obj.setMessage('Initializing')
                    obj.updateProgressBar('increment') 
                    
                    % update state
                    obj.currentState = 'processing segment';
                    
                otherwise
                    obj.throwStateError('start new segment')
            end
            
            obj.refresh()
        end
        
        %% setFileName ----------------------------------------------------
        function setFileName(obj,fn)
        % Sets the name of the current file.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case 'started file'
                    obj.fileName = fn;
                otherwise
                    obj.throwStateError('set file name')
            end
            
            obj.refresh()
        end
        
        %% setFileType ----------------------------------------------------
        function setFileType(obj,ft)
        % Sets the type string of the current file.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case 'started file'
                    switch ft
                        case 'AudioFile'
                            obj.fileType = 'Audio';
                            obj.fileDuration = obj.dFiles(obj.iFile);
                            obj.currentState = 'processing file (pre-segment)';
                        case 'AudioArray'
                            obj.fileType = 'Audio (directory)';
                            obj.fileDuration = obj.dFiles(obj.iFile);
                            obj.currentState = 'processing file (pre-segment)';
                        case 'AllIPIs'
                            obj.fileType = 'Full IPI table';
                            obj.fileDuration = duration(NaN,NaN,NaN);
                            obj.segmentDuration = duration(NaN,NaN,NaN);
                            obj.nSegmentClicksFound = NaN;
                            obj.nSegments = NaN;
                            obj.iSegment = NaN;
                            if isempty(obj.nGridSegments)
                                obj.nGridSegments = 1;
                            else
                                obj.nGridSegments = obj.nGridSegments + 1;
                            end
                            obj.updateProgressBar('increment')
                            obj.currentState = 'processing file (unsegmented)';
                        case 'FilteredIPIs'
                            obj.fileType = 'Filtered IPI table';
                            obj.fileDuration = duration(NaN,NaN,NaN);
                            obj.segmentDuration = duration(NaN,NaN,NaN);
                            obj.nSegmentClicksFound = NaN;
                            obj.nSegments = NaN;
                            obj.iSegment = NaN;
                            if isempty(obj.nGridSegments)
                                obj.nGridSegments = 1;
                            else
                                obj.nGridSegments = obj.nGridSegments + 1;
                            end
                            obj.nFileClicksFound = NaN;
                            obj.updateProgressBar('increment')
                            obj.currentState = 'processing file (unsegmented)';
                        case 'Unsupported'
                            obj.fileType = 'Unsupported';
                            obj.fileDuration = duration(NaN,NaN,NaN);
                            obj.segmentDuration = duration(NaN,NaN,NaN);
                            obj.nSegmentClicksFound = NaN;
                            obj.nSegments = NaN;
                            obj.iSegment = NaN;
                            if isempty(obj.nGridSegments)
                                obj.nGridSegments = 1;
                            else
                                obj.nGridSegments = obj.nGridSegments + 1;
                            end
                            obj.nFileClicksFound = NaN;
                            obj.updateProgressBar('increment')
                            obj.currentState = 'processing file (unsegmented)';
                        otherwise
                            obj.fileType = ft;
                    end
                otherwise
                    obj.throwStateError('set file type')
            end
            
            obj.refresh()
        end
        
        %% setMessage -----------------------------------------------------
        function setMessage(obj,msg)
        % Sets the message.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if isempty(obj.messageHeadStr)
                obj.messageStr = msg;
            else
                obj.messageStr = sprintf('%s\n%s',obj.messageHeadStr,msg);
            end
            
            obj.refresh()
        end
        
        %% setFileDurations -----------------------------------------------
        function setFileDurations(obj,d)
        % Sets the duration of each file.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case 'file count defined'
                    obj.dFiles = d;
                    obj.currentState = 'file durations defined';
                otherwise
                    obj.throwStateError('set file durations')
            end
            
            obj.refresh()
        end
        
        %% setSegmentDuration ------------------------------------------------
        function setSegmentDuration(obj,d)
        % Sets the duration of the current segment.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case 'processing segment'
                    obj.segmentDuration = d;
                otherwise
                    obj.throwStateError('set segment duration')
            end
            
            obj.refresh()
        end
        
        %% setFileClicksFound ---------------------------------------------
        function setFileClicksFound(obj,n)
        % Sets the number of clicks found in a file.
        % Use this only if a file has no segments (i.e. it isn't an audio
        % input).
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case 'processing file (unsegmented)'
                    obj.nFileClicksFound = n;
                otherwise
                    obj.throwStateError('set file click count')
            end
            
            obj.refresh()
        end
        
        %% setSegmentClicksFound --------------------------------------
        function setSegmentClicksFound(obj,n)
        % Sets the number of clicks found in a segment.
        % Also updates the number of clicks in the file.
        % Call this after click detection.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case 'processing segment'
                    % check if segment click count already exists
                    if isempty(obj.nSegmentClicksFound)
                        nClicksOld = 0;
                    else
                        nClicksOld = obj.nSegmentClicksFound;
                    end
                    obj.nSegmentClicksFound = n;
                    
                    % update segment click count
                    if isempty(obj.nFileClicksFound)
                        obj.nFileClicksFound = obj.nSegmentClicksFound;
                    else
                        obj.nFileClicksFound = obj.nFileClicksFound + obj.nSegmentClicksFound - nClicksOld;
                    end
                otherwise
                    obj.throwStateError('set segment click count')
            end
            
            obj.refresh()
        end
        
        %% setFileClicksPassed --------------------------------------------
        function setFileClicksPassed(obj,n)
        % Sets the number of clicks passed in a file.
        % Call this after IPI repetition.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case {'processing file (post-segment)','processing file (unsegmented)'}
                    obj.nFileClicksPassed = n;
                otherwise
                    obj.throwStateError('set good click count')
            end
            
            obj.refresh()
        end
        
        %% endFile --------------------------------------------------------
        function endFile(obj,succeeded)
        % Marks the end of a file.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if succeeded
                switch obj.currentState
                    case {'processing file (post-segment)','processing file (unsegmented)'} 
                        obj.setMessage('Complete')
                        obj.updateMessageHead('none')
                        obj.updateProgressBar('file complete')
                        %obj.assessCompletionTime()
                        if obj.iFile < obj.nFiles
                            obj.currentState = 'completed file';
                        else
                            obj.currentState = 'finished';
                        end
                    otherwise
                        obj.throwStateError('end successful file')
                end
            else
                switch obj.currentState
                    case {...
                            'started file',...
                            'processing file (unsegmented)',...
                            'processing file (pre-segment)',...
                            'processing file (post-segment)',...
                            'processing segment',...
                            'completed segment'}
            
                        obj.setMessage('Failed')
                        obj.updateMessageHead('none')
                        %if any(strcmp(obj.fileType,{'Audio','Audio (directory)'})) &&  isempty(obj.nSegments)
                        %    if isempty(obj.nGridSegments)
                        %        obj.nGridSegments = 1;
                        %    else
                        %        obj.nGridSegments = obj.nGridSegments + 1;
                        %    end
                        %end
                        obj.updateProgressBar('file failed')
                        if obj.iFile < obj.nFiles
                            obj.currentState = 'completed file';
                        else
                            obj.currentState = 'finished';
                        end
                    otherwise
                        obj.throwStateError('end failed file')
                end
            end
            obj.assessCompletionTime()
            obj.refresh()
        end
        
        %% endSegment -----------------------------------------------------
        function endSegment(obj)
        % Marks the end of a segment.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch obj.currentState
                case 'processing segment'
                    obj.updateMessageHead('file')
                    obj.setMessage('Segment complete')
                    %obj.updateProgressBar('segment complete')
                    if obj.iSegment < obj.nSegments
                        obj.currentState = 'completed segment';
                    else
                        obj.currentState = 'processing file (post-segment)';
                    end
                    
                otherwise
                    obj.throwStateError('end segment')
            end
            
            obj.refresh()
        end
        
        %% getFormattedFileInfo -------------------------------------------
        function infoMsg = getFormattedFileInfo(obj)
        % Returns a formatted string of file information.
        % Use this to output file data to log files.
        % Fields include:
        %   -Name
        %   -Type
        %   -Duration
        %   -Clicks Found
        %   -Clicks Passed
        %   -Execution Time
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            fn = obj.h_FileName.String;
            ft = obj.h_FileType.String;
            d = obj.h_FileDuration.String;
            cf = obj.h_FileClicksFound.String;
            cp = obj.h_FileClicksPassed.String;
            et = obj.h_TimeElapsed.String;
            if strcmp(d,'00:00:00')
                d = 'Unknown';
            end
            infoMsg = sprintf(...
                'Name = %s\nType = %s\nDuration = %s\nClicks Found = %s\nClicks Passed = %s\nExecution Time = %s',...
                fn,ft,d,cf,cp,et);
        end
    end
    
    %% METHODS - SETTERS (currentState) ===================================
    methods
        %% set.currentState -----------------------------------------------
        function set.currentState(obj,s)
            obj.currentState = validatestring(s,obj.stateList);
        end
    end
    
    %% METHODS - SETTERS (PRIVATE DEPENDENT PROPERTIES) ===================
    methods
        %% set.messageStr -------------------------------------------------
        function set.messageStr(obj,msg)
            obj.h_Message.String = msg;
        end
        
        %% set.fileName ---------------------------------------------------
        function set.fileName(obj,fn)
            obj.h_FileName.String = fn;
        end
        
        %% set.fileType ---------------------------------------------------
        function set.fileType(obj,ft)
            obj.h_FileType.String = ft;
        end
        
        %% set.fileDuration -----------------------------------------------
        function set.fileDuration(obj,d)
            if isnan(d)
                obj.h_FileDuration.String = 'Unknown';
            else
                obj.h_FileDuration.String = char(d);
            end
        end
        
        %% set.segmentDuration --------------------------------------------
        function set.segmentDuration(obj,d)
            if isnan(d)
                obj.h_SegmentDuration.String = 'N/A';
            else
                obj.h_SegmentDuration.String = char(d);
            end
        end
        
        %% set.nFileClicksFound -------------------------------------------
        function set.nFileClicksFound(obj,n)
            if isnan(n)
                obj.h_FileClicksFound.String = 'Unknown';
            else
                obj.h_FileClicksFound.String = num2str(n);
            end
        end
        
        %% set.nSegmentClicksFound ----------------------------------------
        function set.nSegmentClicksFound(obj,n)
            if isnan(n)
                obj.h_SegmentClicksFound.String = 'N/A';
            else
                obj.h_SegmentClicksFound.String = num2str(n);
            end
        end
        
        %% set.nFileClicksPassed ------------------------------------------
        function set.nFileClicksPassed(obj,n)
            %obj.h_FileClicksPassed.String = num2str(n);
            if isempty(n)
                obj.h_FileClicksPassed.String = '';
            elseif isnan(obj.nFileClicksFound)
                obj.h_FileClicksPassed.String = num2str(n);
            else
                percentClicksPassed = (n/obj.nFileClicksFound)*100;
                obj.h_FileClicksPassed.String = sprintf('%d (%.2f%%)',n,percentClicksPassed);
            end
        end
        
        %% set.dtLaunch ---------------------------------------------------
        function set.dtLaunch(obj,dt)
            obj.h_LaunchTime.String = char(dt);
        end
        
        %% set.dtCompletion -----------------------------------------------
        function set.dtCompletion(obj,dt)
            obj.h_CompletionTime.String = char(dt);
        end
    end
    
    %% METHODS - GETTERS (PRIVATE DEPENDENT PROPERTIES) ===================
    methods
        %% get.messageStr -------------------------------------------------
        function msg = get.messageStr(obj)
            msg = strjoin(cellstr(obj.h_Message.String),'\n');
        end
        
        %% get.fileName ---------------------------------------------------
        function fn = get.fileName(obj)
            fn = obj.h_FileName.String;
        end
        
        %% get.fileType ---------------------------------------------------
        function ft = get.fileType(obj)
            ft = obj.h_FileType.String;
        end
        
        %% get.fileDuration -----------------------------------------------
        function d = get.fileDuration(obj)
            dStr = obj.h_FileDuration.String;
            if isempty(dStr)
                d = duration.empty;
            elseif strcmp(dStr,'Unknown')
                d = duration(NaN,NaN,NaN);
            else
                d = obj.char2dur(dStr);
            end
        end
        
        %% get.segmentDuration --------------------------------------------
        function d = get.segmentDuration(obj)
            dStr = obj.h_SegmentDuration.String;
            if isempty(dStr)
                d = duration.empty;
            elseif strcmp(dStr,'N/A')
                d = duration(NaN,NaN,NaN);
            else
                d = obj.char2dur(dStr);
            end
        end
        
        %% get.nFileClicksFound -------------------------------------------
        function n = get.nFileClicksFound(obj)
            nStr = obj.h_FileClicksFound.String;
            if isempty(nStr)
                n = [];
            elseif strcmp(nStr,'Unknown')
                n = NaN;
            else
                n = str2double(nStr);
            end
        end
        
        %% get.nSegmentClicksFound ----------------------------------------
        function n = get.nSegmentClicksFound(obj)
            nStr = obj.h_SegmentClicksFound.String;
            if isempty(nStr)
                n = [];
            elseif strcmp(nStr,'N/A')
                n = NaN;
            else
                n = str2double(nStr);
            end
        end
        
        %% get.nFileClicksPassed ------------------------------------------
        function n = get.nFileClicksPassed(obj)
            nStr = obj.h_FileClicksPassed.String;
            if isempty(nStr)
                n = [];
            else
                %n = str2double(nStr);
                nStr = strtok(obj.h_FileClicksPassed.String);
                n = str2double(nStr);
            end
        end
        
        %% get.dtLaunch ---------------------------------------------------
        function dt = get.dtLaunch(obj)
            dtStr = obj.h_LaunchTime.String;
            if isempty(dtStr)
                dt = datetime.empty;
            else
                dt = datetime(dtStr);
            end
        end
        
        %% get.dtCompletion -----------------------------------------------
        function dt = get.dtCompletion(obj)
            dtStr = obj.h_CompletionTime.String;
            if isempty(dtStr)
                dt = datetime.empty;
            else
                dt = datetime(dtStr);
            end
        end
    end
    
    %% METHODS - PRIVATE ==================================================
    methods (Access = private)
        %% refresh --------------------------------------------------------
        function refresh(obj)
        % Refreshes the UI to display most up-to-date info.
        % If a UI callback is programmed to change the abort flag, that 
        % will also be assessed here.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.updateTimer()
            drawnow
            if obj.abort
                error('Program terminated by user')
            end
        end
        
        %% resetTimer -----------------------------------------------------
        function resetTimer(obj)
        % Clears all time information from internal storage and UI display.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.dtLaunch = datetime.empty;
            obj.dtCompletion = datetime.empty;
            obj.dtUpdated = datetime.empty;
            obj.h_LaunchTime.String = '';
            obj.h_TimeElapsed.String = '';
            obj.h_CompletionTime.String = '';
            obj.h_TimeRemaining.String = '';
        end
        
        %% updateTimer ----------------------------------------------------
        function updateTimer(obj)
        % Updates the time elapsed.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.dtUpdated = datetime('now');
            if ~isempty(obj.dtLaunch)
                tElapsed = obj.dtUpdated - obj.dtLaunch;
                obj.h_TimeElapsed.String = char(tElapsed);
                if ~isempty(obj.dtCompletion)
                    tRemaining = obj.dtCompletion - obj.dtUpdated;
                    obj.h_TimeRemaining.String = char(tRemaining);
                end
            end
        end
        
        %% assessCompletionTime -------------------------------------------
        function assessCompletionTime(obj)
        % Infers how long it will take to complete the run.
        % This should be called from within endFile.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            iFilesComplete = 1:obj.iFile;
            dFilesCompleteTotal = sum(obj.dFiles(iFilesComplete));
            dFilesTotal = sum(obj.dFiles);
            dFilesRemainingTotal = dFilesTotal - dFilesCompleteTotal;
            obj.updateTimer()
            tElapsed = obj.dtUpdated - obj.dtLaunch;
            tRemaining = tElapsed*(dFilesRemainingTotal/dFilesCompleteTotal);
            if ~isinf(tRemaining) && ~isnan(tRemaining)
                obj.dtCompletion = obj.dtUpdated + tRemaining;
                obj.updateTimer()
            end
        end
        
        %% updateMessageHead ----------------------------------------------
        function updateMessageHead(obj,dataType)
        % Sets the message header based on the current step: if a whole 
        % file or segment is being analyzed.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch dataType
                case 'none'
                    obj.messageHeadStr = '';
                case 'file'
                    obj.messageHeadStr = sprintf('File %d/%d:',obj.iFile,obj.nFiles);
                case 'segment'
                    obj.messageHeadStr = sprintf('File %d/%d, segment %d/%d:',obj.iFile,obj.nFiles,obj.iSegment,obj.nSegments);
                otherwise
                    error('Unrecognized data type')
            end
        end
        
        %% updateProgressBar
        function updateProgressBar(obj,updateType)
            switch updateType
                case 'initialize'
                    nf = obj.nFiles;
                    ns = 1;
                    % initialize segment grid
                    [xs,ys,zs,cs] = obj.buildMeshGrid([0,nf],[0,1],0,ns);
                    obj.h_surfaceSegmentProgress = surface(xs,ys,zs,cs,'LineWidth',0.5,'EdgeAlpha',0.2,'Parent',obj.h_axesProgress);
                    % initialize file grid
                    [xf,yf,zf,cf] = obj.buildMeshGrid([0,nf],[0,1],1,nf);
                    obj.h_surfaceFileProgress = surface(xf,yf,zf,cf,'FaceColor','none','LineWidth',1,'EdgeAlpha',0.5,'Parent',obj.h_axesProgress);
                    % set axes limits
                    xlim(obj.h_axesProgress,[0,nf])
                    ylim(obj.h_axesProgress,[0,1])
                    
                case 'increment'
                    % fill the next bar in the segment surface with yellow.
                    % If the bars haven't been created yet (new file),
                    % create them.
                    
                    %%% define colour
                    col = [255 205 55]/255; % yellow
                    
                    %%% get index of bar segment to modify
                    if isnan(obj.nSegments)
                        nSegmentsIP = 1;
                        iSegmentIP = 1;
                    else
                        nSegmentsIP = obj.nSegments;
                        iSegmentIP = obj.iSegment;
                    end
                    nSegmentsComplete = obj.nGridSegments - nSegmentsIP;
                    
                    %%% add new bars if they don't exist yet
                    if obj.iSegment == 1 || isnan(obj.iSegment)
                        idx = nSegmentsComplete+1 : obj.nGridSegments;
                        n = numel(idx);
                        idxGrid = cell(1,n);
                        for ii = 1:n
                            idxGrid{ii} = 2*idx(ii) - [1,0];
                        end
                        idxGrid = cell2mat(idxGrid);
                        [xNew,yNew,zNew,cNew] = obj.buildMeshGrid([obj.iFile-1,obj.iFile],[0,1],0,nSegmentsIP);
                        obj.h_surfaceSegmentProgress.XData(:,idxGrid) = xNew;...
                        obj.h_surfaceSegmentProgress.YData(:,idxGrid) = yNew;...
                        obj.h_surfaceSegmentProgress.ZData(:,idxGrid) = zNew;...
                        obj.h_surfaceSegmentProgress.CData(:,idxGrid,:) = cNew;
                    end
                    
                    %%% set current segment colour
                    colSliceNew = repelem(reshape(col,1,1,3),2,2); % [2x2x3] matrix
                    idxColMat = 2*(nSegmentsComplete + iSegmentIP) -[1,0];
                    obj.h_surfaceSegmentProgress.CData(:,idxColMat,:) = colSliceNew;
                    
                case {'file complete','file failed'}
                    % fills every segment bar in a file with green if
                    % successful, red if not.
                    
                    %%% get colour
                    if strcmp(updateType,'file complete')
                        col = [0 225 0]/255; % green
                    else
                        col = [255 55 55]/255; % red
                    end
                    
                    %%% get segment indices
                    if isnan(obj.iSegment)
                        % file is not segmented
                        nSegmentsComplete = obj.nGridSegments - 1;
                    elseif isempty(obj.iSegment)
                        % segments were not yet defined
                        %%% update nGridSegments
                        if isempty(obj.nGridSegments)
                            obj.nGridSegments = 1;
                        else
                            obj.nGridSegments = obj.nGridSegments + 1;
                        end
                        nSegmentsComplete = obj.nGridSegments - 1;
                        
                        %%% add new bar (because it wasn't created yet)
                        nSegmentsIP = 1;
                        idx = nSegmentsComplete+1 : obj.nGridSegments;
                        idxGrid = 2*idx - [1,0];
                        [xNew,yNew,zNew,cNew] = obj.buildMeshGrid([obj.iFile-1,obj.iFile],[0,1],0,nSegmentsIP);
                        obj.h_surfaceSegmentProgress.XData(:,idxGrid) = xNew;...
                        obj.h_surfaceSegmentProgress.YData(:,idxGrid) = yNew;...
                        obj.h_surfaceSegmentProgress.ZData(:,idxGrid) = zNew;...
                        obj.h_surfaceSegmentProgress.CData(:,idxGrid,:) = cNew;
                    else
                        % file has segments
                        nSegmentsComplete = obj.nGridSegments - obj.nSegments;
                    end
                    idx = nSegmentsComplete+1 : obj.nGridSegments;
                    n = numel(idx);
                    idxGrid = cell(1,n);
                    for ii = 1:n
                        idxGrid{ii} = 2*idx(ii) - [1,0];
                    end
                    idxGrid = cell2mat(idxGrid);
                    idxColMat = idxGrid;
                    
                    %%% set colour of file segments
                    colSliceNew = repelem(reshape(col,1,1,3),2,numel(idxColMat));
                    obj.h_surfaceSegmentProgress.CData(:,idxColMat,:) = colSliceNew;    
                    
                case 'reset'
                    cla(obj.h_axesProgress)
            end
        end
        
        %% throwStateError ------------------------------------------------
        function throwStateError(obj,action)
        % Throws a standardized error message relating to current state.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            error('Cannot %s during state ''%s''',action,obj.currentState)
        end
    end
    
    %% METHODS - PRIVATE STATIC ===========================================
    methods (Access = private, Static)
        %% char2dur -------------------------------------------------------
        function d = char2dur(c)
        % Converts a string of the form 'HH:MM:SS' to a duration object.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            dhms = cell2mat(textscan(c,'%f','Delimiter',':'));
            if dhms(1) < 0
                dhms = -abs(dhms);
            end
            d = duration(dhms(1),dhms(2),dhms(3));
        end
        
        %% buildMeshGrid --------------------------------------------------
        function [x,y,z,c] =  buildMeshGrid(xRange,yRange,height,n)
        % Creates a mesh grid to be used for the progress bar surface.
        % Output grid consists of "n" 2x2 squares (joined into a row 
        % matrix). Colour is 3D matrix where RGB values are encoded in
        % depth (red = (:,:,1), blue = (:,:,2), green = (:,:,3)). The
        % output colour here is pure white.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            n2 = n*2;
            xRaw = linspace(xRange(1),xRange(2),n+1);
            x = repmat(sort([xRaw(1:end-1),xRaw(2:end)]),2,1);
            y = repmat([yRange(1);yRange(2)],1,n2);
            z = repelem(height,2,n2);
            c = ones(2,n2,3);
        end
    end
end