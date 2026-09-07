%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Class "UIStateManager"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       none
%   
%   Description:
%       Class for controlling the on/off state of GUI components. It allows
%       groups of GUI components to be activated and deactivated together.
%       For components with which a user can interact (e.g. pushbuttons),
%       the state is controlled by directly toggling its 'Enable' property. 
%       For GUI components that do not have an 'Enable' property (like 
%       panels), the "off" state is conveyed by graying out the font.
%       
%       Note that "on/off" here does not refer to the 'Enable' value of 
%       individual components. Rather, it is the GROUP of components that 
%       is considered to be "on" or "off". It is perfectly fine for some 
%       components within the group to have an 'Enable' property equal to 
%       'off' or 'inactive' during the "on" state. When creating an 
%       instance, the class assumes that its UI component group is in the 
%       "on" state, and saves the current value of the 'Enable' property of 
%       each component. When state is toggled to "off", each 'Enable' 
%       property is also set to 'off'. But when reverting back to "on", the 
%       'Enable' properties are reset to their original values, regardless 
%       of what these are. It is also possible to change what the "on"
%       value of a component's 'Enable' property is after construction.
%
%   Constructor Input:
%       uiHandleArray [n-by-m Graphics]:
%           Array of graphics object handles, such as UIControls and/or 
%           UIPanels. Can be any size, but it really makes most sense for 
%           this to be a vector.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

classdef UIStateManager < handle
    %% PROPERTIES =========================================================
    properties (Constant)
        offFontColour = [131 131 131]/255;  % Font colour to express during "off" state
    end
    properties (SetAccess = private)
        hUI                 % Array of graphics object handles
        activeStateValue    % Cell array of 'Enable' property values for each component (if present) during the "on" state
        currentState        % String equal to 'on' or 'off'
    end
    
    %% METHODS - PUBLIC ===================================================
    methods
        %% Constructor ----------------------------------------------------
        function obj = UIStateManager(uiHandleArray)
            % validate input
            assert(all(isgraphics(uiHandleArray)),'Expected input to be an array of valid graphics handles')
            
            % get relevant properties
            arraySize = size(uiHandleArray);
            currentStateValue = cell(arraySize);
            for ii = 1:prod(arraySize)
                hii = uiHandleArray(ii);
                if isprop(hii,'Enable')
                    vii = hii.Enable;
                elseif isprop(hii,'ForegroundColor')
                    vii = hii.ForegroundColor;
                end
                currentStateValue{ii} = vii;
            end
            
            % assign properties
            obj.hUI = uiHandleArray;
            obj.activeStateValue = currentStateValue;
            obj.currentState = 'on';
        end
        
        %% toggleState ----------------------------------------------------
        function toggleState(obj,newState)
        % Activates or deactivates all stored UI handles.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~strcmp(obj.currentState,newState)
                nh = numel(obj.hUI);
                switch newState
                    case 'on'
                        for ii = 1:nh
                            hii = obj.hUI(ii);
                            if isprop(hii,'Enable')
                                hii.Enable = obj.activeStateValue{ii};
                            elseif isprop(hii,'ForegroundColor')
                                hii.ForegroundColor = obj.activeStateValue{ii};
                            end
                        end
                    case 'off'
                        for ii = 1:nh
                            hii = obj.hUI(ii);
                            if isprop(hii,'Enable')
                                hii.Enable = 'off';
                            elseif isprop(hii,'ForegroundColor')
                                hii.ForegroundColor = obj.offFontColour;
                            end
                        end
                    otherwise
                        error('Unrecognized state')
                end
                obj.currentState = newState;
            end
        end
        
        %% changeActiveStateValue -----------------------------------------
        function changeActiveStateValue(obj,h,v)
        % Changes the value that a UI component should assume during the 
        % active state.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            lh = ismember(obj.hUI,h);
            assert(sum(lh) == 1, 'Expected input to be a handle contained in this UIStateManager instance')
            
            % save new value, and assign it if state is 'on'
            obj.activeStateValue{lh} = v;
            if strcmp(obj.currentState,'on')
                if isprop(h,'Enable')
                    h.Enable = v;
                elseif isprop(h,'ForegroundColor')
                    h.ForegroundColor = v;
                end
            end
        
            % VECTOR VERSION
            %{
            nInputs = numel(h);
            
            % find indices of UI handles
            lh = ismember(obj.hUI,h);
            assert(sum(lh) == nInputs, 'One or more input handles was not found in this UIStateManager instance')
            
            % make values input a cell if it isn't (allowed in scalar case only)
            if nInputs == 1 && ~iscell(v)
                v = {v};
            end
            
            % make sure number of elements are consistent
            assert(numel(h) == numel(v),'Number of elements in input parameters are not consistent')
            
            % save new values, and assign them if state is 'on'
            obj.activeStateValue(lh) = v;
            if strcmp(obj.currentState,'on')
                ih = find(lh);
                for ii = 1:nInputs
                    iii = ih(ii);
                    hii = obj.hUI(iii);
                    vii = v{ii};
                    if isprop(hii,'Enable')
                        hii.Enable = vii;
                    elseif isprop(hii,'ForegroundColor')
                        hii.ForegroundColor = vii;
                    end
                end
            end
            %}
        end
    end
end