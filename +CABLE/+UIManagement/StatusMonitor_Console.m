%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Class "StatusMonitor_Console"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies: 
%       none
%
%   Description:
%       This is a trimmed-down alternative to the "StatusMonitor" class for 
%       use when there is no GUI. All it does is print messages to the 
%       console.
%
%   Constructor Syntax:
%       obj = StatusMonitor_Console()
%       obj = StatusMonitor_Console(doPrint)
%
%   Constructor Input:
%       doPrint [1-by-1 logical]:
%           Specifies if updates should be printed to the console or not.
%           Default is true. If false, then the object does pretty much 
%           nothing at all besides taking input.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

classdef StatusMonitor_Console < handle
    %% PROPERTIES =========================================================
    properties
        verbose     % Specifies if messages should be displayed or not
    end
    properties (SetAccess = private)
        nSegments
        nSegmentsComplete
        iSegment
        nSegmentClicksFound
        nFileClicksFound
    end
    properties (SetAccess = private, Dependent)
        messageHeadStr
    end
    
    %% METHODS - PUBLIC ===================================================
    methods
        %% Constructor ----------------------------------------------------
        function obj = StatusMonitor_Console(varargin)
        % Creates a 'StatusMonitor_Console' instance
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            narginchk(0,1)
            if nargin == 0
                obj.verbose = true;
            else
                obj.verbose = varargin{:};
            end
            obj.reset();
        end
        
        %% set.verbose ----------------------------------------------------
        function set.verbose(obj,v)
            validateattributes(v,{'logical'},{'scalar'})
            obj.verbose = v;
        end
        
        %% get.messageHeadStr ---------------------------------------------
        function m = get.messageHeadStr(obj)
            if obj.iSegment > obj.nSegmentsComplete 
                m = sprintf('Segment %d/%d: ',obj.iSegment,obj.nSegments);
            else
                m = '';
            end
        end
        
        %% reset ----------------------------------------------------------
        function reset(obj)
            obj.nSegments = 0;
            obj.nSegmentsComplete = 0;
            obj.iSegment = 0;
            obj.nSegmentClicksFound = 0;
            obj.nFileClicksFound = 0;
        end

        %% setFileType ----------------------------------------------------
        function setFileType(obj,ft)
            msg = sprintf('File Type = %s',ft);
            obj.setMessage(msg)
        end
        
        %% setSegmentCount ------------------------------------------------
        function setSegmentCount(obj,n)
            obj.nSegments = n;
            
            msg = sprintf('File broken into %d segments',n);
            obj.setMessage(msg)
        end
        
        %% newSegment -----------------------------------------------------
        function newSegment(obj)
            obj.iSegment = obj.iSegment + 1;
            
            msg = 'Started';
            obj.setMessage(msg)
        end
        
        %% setSegmentDuration ---------------------------------------------
        function setSegmentDuration(obj,d)
            msg = ['Duration = ',char(d)];
            obj.setMessage(msg)
        end
        
        %% setFileClicksFound ---------------------------------------------
        function setFileClicksFound(obj,n)
        % Sets the number of clicks found in a file.
        % Use this only if a file has no segments (i.e. it isn't an audio
        % input).
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.nFileClicksFound = n;
            
            msg = sprintf('File has %d clicks',obj.nFileClicksFound);
            obj.setMessage(msg)
        end
        
        %% setSegmentClicksFound ------------------------------------------
        function setSegmentClicksFound(obj,n)
            obj.nSegmentClicksFound = n;
            obj.nFileClicksFound = obj.nSegmentClicksFound + obj.nFileClicksFound;
            
            msg = sprintf('Detected %d clicks (total = %d)',n,obj.nFileClicksFound);
            obj.setMessage(msg)
        end
        
        %% endSegment -----------------------------------------------------
        function endSegment(obj)
            obj.nSegmentsComplete = obj.nSegmentsComplete + 1;
            obj.nSegmentClicksFound = 0;
            
            msg = sprintf('Segment %d/%d completed',obj.iSegment,obj.nSegments);
            obj.setMessage(msg)
        end
        
        %% setFileClicksPassed --------------------------------------------
        function setFileClicksPassed(obj,n)
            msg = sprintf('Total clicks passed = %d/%d (%.2f%%)',n,obj.nFileClicksFound,(n/obj.nFileClicksFound)*100);
            obj.setMessage(msg)
        end
        
        %% setMessage -----------------------------------------------------
        function setMessage(obj,msg)
            if obj.verbose
                disp([obj.messageHeadStr,msg])
            end
        end
    end
end