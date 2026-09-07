%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Class "PlotManager"
% Last Updated Dec 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       none
%
%   Description:
%       Class for controlling all aspects IPI distribution and cluster 
%       plotting. This includes management of all GUI components that deal 
%       with plotting. Specific tasks include:
%           - Association of GUI components to specific plotting functions
%           - Loading and clearing of output data produced by CABLE for the 
%           purpose of plotting
%           - Plot creation
%           - Cycling between different models (only one plot can be 
%           displayed at a time)
%           - Output of plot image files
%           - Validation of plot property values and image file settings 
%           set by the user, and the display of associated warnings
%           - Retrival of plot property values and image file settings from 
%           the GUI, and their conversion into appropriate data types
%           - Updating of plot when property values are changed. This
%           includes a resizing response (which is actually quite
%           compilcated when you have multiple overlapping axes!).
%
%   Constructor Syntax:
%       obj = PlotManager(sm,hcp,hpc,hps,<Name>,<Value>)
%
%   Constructor Input:
%       sm [1-by-1 UIStateManager]:
%           State manager object controlling GUI component (de)activation
%       hcp [1-by-1 matlab.ui.control.UIControl]:
%           Handle to popup menu controlling plot cycling
%       hpc [1-by-1 matlab.ui.control.UIControl]:
%           Handle to pushbutton controlling data clearing
%       hps [1-by-1 matlab.ui.control.UIControl]:
%           Handle to pushbutton controlling image saving
%
%   Name-Value Pairs:
%       These correspond to the handles of each GUI component that controls 
%       plot appearance and image settings. They are all required. See the 
%       constructor for the full list.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DEV NOTES:
% - It would be nice to include information on body lengths. Perhaps I 
%   could allow transformation of the X-axis from IPI to length. There's a 
%   problem with this though: the transformation won't necessarily be
%   linear (e.g. if using Gordon's equation). The tick marks may not be
%   uniformly spaced, which is not supported by bar graphs. Possible 
%   workarounds to this include:
%       - Use histogram instead (will lose control over edge thickness)
%       - Make creative use of area plots
%   A simple approach would be to just note the mean length in the legend
%   or at the peaks.

classdef PlotManager < handle
    %% PROPERTIES =========================================================
    properties (Constant)
        paramList = {...
            %%% Display & Saving
            'figUnits';...
            'figWidth';...
            'figHeight';...
            'printResolution';...
            'renderer';...
            'printFileTypes';...
            'printArgs';...
            %%% Appearance - Axes
            'axesBoxVisible';...
            'axesTitleVisible';...
            'axesXLabelsVisible';...
            'axesYLabelsVisible_Count';...
            'axesYLabelsVisible_PD';...
            'axesXMin';...
            'axesXMax';...
            'axesYMax_Count';...
            'axesYMax_PD';...
            'axesTickDir';...
            'axesTickLength';...
            'axesLineWidth';...
            'axesFont';...
            'axesLabelFontSizeMultiplier';...
            'axesTitleFontSizeMultiplier';...
            'axesTitleFontWeight';...
            %%% Appearance - Legend
            'legendEnable';...
            'legendBoxVisible';...
            'legendLineWidth';...
            'legendFont';...
            %%% Appearance - Histogram
            'histEnable';...
            'histFaceColor';...
            'histEdgeColor';...
            'histLineStyle';...
            'histLineWidth';...
            %%% Appearance - Lines
            'linesColormap';...
            'linesLineStyle';...
            'linesLineWidth'}
    end
    properties
        stateManager            % UIStateManager object
        h_popupmenuCurrentPlot  % Handle to UI component controlling plot cycling
        h_pushbuttonClear       % Handle to UI component controlling data clearing
        h_pushbuttonSave        % Handle to UI component controlling plot image saving
    end
    properties (Constant, Hidden)
        colourValid = [1 1 1];              % Colour of GUI edit field when a setting is valid
        colourInvalid = [255 205 205]/255;  % Colour of GUI edit field when a setting is invalid
    end
    properties (SetAccess = private)
        % DATA
        dataName        % Name of data (file) being plotted
        dataDir         % Path to directory containing source data
        IPIs            % IPI distribution vector
        GMMTables       % Cell array containing tables for each GMM
        deltaBICs       % Vector of Delta BIC values for each model
        Fs              % Sampling rate, in Hertz
        IPIRange        % Minimum and maximum expected IPI values
        plotVisible     % Logical specifying if plot is visible or not
        
        % HANDLES
        hFig            % Plot figure window
        hAxesBase       % Base axes (controls x-axis)
        hAxesCount      % Count axes (controls left y-axis)
        hAxesPD         % Probability density axes (controls right y-axis)
        hLegend         % Legend
        hHist           % IPI distribution histogram
        hLines          % Cell array containing cluster line handle arrays. Cells correspond to models.
        hLinkX          % x-axis link handle. Allows the base axes to control the x-axis of the other two axes.
    end
    properties (SetAccess = private, Dependent)
        figExists               % Logical specifying if a plot figure exists
        legendExists            % Logical specifying if a legend exists
        dataName_Uninterpreted  % The data name string, modified so that special characters are not interpreted as TeX formatting operators
        nIPIs                   % Total number of IPIs in distribution
        nGMMs                   % Number of plausible mixture models
        binWidth                % IPI histogram bin width
        activeModel             % Index of model currently displayed
        scale_PD2Count          % Scale factor for converting from probability density to count
        scale_Count2PD          % Scale factor for converting from count to probability density
    end
    properties (SetAccess = private, Hidden)
        paramTable      % Table of data associated with each plot setting
        xMin_auto       % Automatic lower x-axis limit
        xMax_auto       % Automatic upper x-axis limit
        yMaxPD_auto     % Automatic upper y-axis limit for probability density axis
        figUnitsOld     % Previously used figure size units
    end
    
    %% METHODS - PUBLIC ===================================================
    methods
        %% Constructor ----------------------------------------------------
        function obj = PlotManager(sm,hcp,hpc,hps,varargin)
        % Creates a PlotManager object.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
             % initialize variables
            validUIObject = @(h) validateattributes(h,{'matlab.ui.control.UIControl','matlab.ui.control.Table'},{'scalar'});
            p = inputParser;
            p.CaseSensitive = true;
            p.PartialMatching = false;
            
            % set handles for Current Plot menu, clear button, and save
            % button
            obj.stateManager = sm;
            obj.h_popupmenuCurrentPlot = hcp;
            obj.h_pushbuttonClear = hpc;
            obj.h_pushbuttonSave = hps;
            
            % parse other UIHandle input
            p.addParameter('figUnits',[],validUIObject)
            p.addParameter('figWidth',[],validUIObject)
            p.addParameter('figHeight',[],validUIObject)
            p.addParameter('printResolution',[],validUIObject)
            p.addParameter('renderer',[],validUIObject)
            p.addParameter('printFileTypes',[],validUIObject)
            p.addParameter('printArgs',[],validUIObject)
            p.addParameter('axesBoxVisible',[],validUIObject)
            p.addParameter('axesTitleVisible',[],validUIObject)
            p.addParameter('axesXLabelsVisible',[],validUIObject)
            p.addParameter('axesYLabelsVisible_Count',[],validUIObject)
            p.addParameter('axesYLabelsVisible_PD',[],validUIObject)
            p.addParameter('axesXMin',[],validUIObject)
            p.addParameter('axesXMax',[],validUIObject)
            p.addParameter('axesYMax_Count',[],validUIObject)
            p.addParameter('axesYMax_PD',[],validUIObject)
            p.addParameter('axesTickDir',[],validUIObject)
            p.addParameter('axesTickLength',[],validUIObject)
            p.addParameter('axesLineWidth',[],validUIObject)
            p.addParameter('axesFont',[],validUIObject)
            p.addParameter('axesLabelFontSizeMultiplier',[],validUIObject)
            p.addParameter('axesTitleFontSizeMultiplier',[],validUIObject)
            p.addParameter('axesTitleFontWeight',[],validUIObject)
            p.addParameter('legendEnable',[],validUIObject)
            p.addParameter('legendBoxVisible',[],validUIObject)
            p.addParameter('legendLineWidth',[],validUIObject)
            p.addParameter('legendFont',[],validUIObject)
            p.addParameter('histEnable',[],validUIObject)
            p.addParameter('histFaceColor',[],validUIObject)
            p.addParameter('histEdgeColor',[],validUIObject)
            p.addParameter('histLineStyle',[],validUIObject)
            p.addParameter('histLineWidth',[],validUIObject)
            p.addParameter('linesColormap',[],validUIObject)
            p.addParameter('linesLineStyle',[],validUIObject)
            p.addParameter('linesLineWidth',[],validUIObject)
            
            p.parse(varargin{:})
            
            %%% make sure everything was set
            if ~isempty(p.UsingDefaults)
                error('Missing the following inputs:\n%s',strjoin(p.UsingDefaults))
            end
        
            % define default values
            %%% get some root defaults
            droot_figPos = get(groot,'defaultFigurePosition');
            droot_tickLength = get(groot,'defaultAxesTickLength');
            
            %%% define parameter defaults
            default_figUnits = get(groot,'defaultFigureUnits');
            default_figWidth = droot_figPos(3);
            default_figHeight = droot_figPos(4);
            default_printResolution = 'screen';
            default_renderer = get(groot,'defaultFigureRenderer');
            default_printFileTypes = 'png';
            default_printArgs = {}; % not actually used
            default_axesBoxVisible = 'on'; %get(groot,'defaultAxesBox');
            default_axesTitleVisible = 'on';
            default_axesXLabelsVisible = 'on';
            default_axesYLabelsVisible_Count = 'on';
            default_axesYLabelsVisible_PD = 'on';
            default_axesXMin = 'auto';
            default_axesXMax = 'auto';
            default_axesYMax_Count = 'auto';
            default_axesYMax_PD = 'auto';
            default_axesTickDir = get(groot,'defaultAxesTickDir');
            default_axesTickLength = droot_tickLength(1);
            default_axesLineWidth = get(groot,'defaultAxesLineWidth');
            default_axesFont = struct(...
                'FontName',get(groot,'defaultAxesFontName'),...
                'FontUnits',get(groot,'defaultAxesFontUnits'),...
                'FontSize',get(groot,'defaultAxesFontSize'),...
                'FontWeight',get(groot,'defaultAxesFontWeight'),...
                'FontAngle',get(groot,'defaultAxesFontAngle'));
            default_axesLabelFontSizeMultiplier = get(groot,'defaultAxesLabelFontSizeMultiplier');
            default_axesTitleFontSizeMultiplier = get(groot,'defaultAxesTitleFontSizeMultiplier');
            default_axesTitleFontWeight = get(groot,'defaultAxesTitleFontWeight');
            default_legendEnable = 'on';
            default_legendBoxVisible = get(groot,'defaultLegendBox');
            default_legendLineWidth = get(groot,'defaultLegendLineWidth');
            default_legendFont = struct(...
                'FontName',get(groot,'defaultLegendFontName'),...
                'FontUnits',get(groot,'defaultLegendFontUnits'),...
                'FontSize',get(groot,'defaultLegendFontSize'),...
                'FontWeight',get(groot,'defaultLegendFontWeight'),...
                'FontAngle',get(groot,'defaultLegendFontAngle'));
            default_histEnable = 'on';
            default_histFaceColor = [195 225 245]/255;
            default_histEdgeColor = [0 0 0];
            default_histLineStyle = 'solid';
            default_histLineWidth = get(groot,'defaultBarLineWidth');
            default_linesColormap = 'lines';
            default_linesLineStyle = 'solid';
            default_linesLineWidth = 1;
            
            % create initialization cell.
            % The first column corresponds to parameter names.
            % The remaining columns correspond to the fields in the table:
            tableFields = {'Default','UIHandle','UpdateFunction','ValidationFunction'};
            initCell = {...
                'figUnits', default_figUnits, p.Results.figUnits, @update_figUnits, function_handle.empty(0);...
                'figWidth', default_figWidth, p.Results.figWidth, @update_figWidth, @validate_figWidth;...
                'figHeight', default_figHeight, p.Results.figHeight, @update_figHeight, @validate_figHeight;...
                'printResolution', default_printResolution, p.Results.printResolution, function_handle.empty(0), @validate_printResolution;...
                'renderer', default_renderer, p.Results.renderer, @update_renderer, function_handle.empty(0);...
                'printFileTypes', default_printFileTypes, p.Results.printFileTypes, @update_printFileTypes, function_handle.empty(0);...
                'printArgs', default_printArgs, p.Results.printArgs, function_handle.empty(0), function_handle.empty(0);...
                'axesBoxVisible', default_axesBoxVisible, p.Results.axesBoxVisible, @update_axesBoxVisible, function_handle.empty(0);...
                'axesTitleVisible', default_axesTitleVisible, p.Results.axesTitleVisible, @update_axesTitleVisible, function_handle.empty(0);...
                'axesXLabelsVisible', default_axesXLabelsVisible, p.Results.axesXLabelsVisible, @update_axesXLabelsVisible, function_handle.empty(0);...
                'axesYLabelsVisible_Count', default_axesYLabelsVisible_Count, p.Results.axesYLabelsVisible_Count, @update_axesYLabelsVisible_Count, function_handle.empty(0);...
                'axesYLabelsVisible_PD', default_axesYLabelsVisible_PD, p.Results.axesYLabelsVisible_PD, @update_axesYLabelsVisible_PD, function_handle.empty(0);...
                'axesXMin', default_axesXMin, p.Results.axesXMin, @update_axesXMin, @validate_axesXMin;...
                'axesXMax', default_axesXMax, p.Results.axesXMax, @update_axesXMax, @validate_axesXMax;...
                'axesYMax_Count', default_axesYMax_Count, p.Results.axesYMax_Count, @update_axesYMax_Count, @validate_axesYMax_Count;...
                'axesYMax_PD', default_axesYMax_PD, p.Results.axesYMax_PD, @update_axesYMax_PD, @validate_axesYMax_PD;...
                'axesTickDir', default_axesTickDir, p.Results.axesTickDir, @update_axesTickDir, function_handle.empty(0);...
                'axesTickLength', default_axesTickLength, p.Results.axesTickLength, @update_axesTickLength, @validate_axesTickLength;...
                'axesLineWidth', default_axesLineWidth, p.Results.axesLineWidth, @update_axesLineWidth, @validate_axesLineWidth;...
                'axesFont', default_axesFont, p.Results.axesFont, @update_axesFont, function_handle.empty(0);...
                'axesLabelFontSizeMultiplier', default_axesLabelFontSizeMultiplier, p.Results.axesLabelFontSizeMultiplier, @update_axesLabelFontSizeMultiplier, @validate_axesLabelFontSizeMultiplier;...
                'axesTitleFontSizeMultiplier', default_axesTitleFontSizeMultiplier, p.Results.axesTitleFontSizeMultiplier, @update_axesTitleFontSizeMultiplier, @validate_axesTitleFontSizeMultiplier;...
                'axesTitleFontWeight', default_axesTitleFontWeight, p.Results.axesTitleFontWeight, @update_axesTitleFontWeight, function_handle.empty(0);...
                'legendEnable', default_legendEnable, p.Results.legendEnable, @update_legendEnable, function_handle.empty(0);...
                'legendBoxVisible', default_legendBoxVisible, p.Results.legendBoxVisible, @update_legendBoxVisible, function_handle.empty(0);...
                'legendLineWidth', default_legendLineWidth, p.Results.legendLineWidth, @update_legendLineWidth, @validate_legendLineWidth;...
                'legendFont', default_legendFont, p.Results.legendFont, @update_legendFont, function_handle.empty(0);...
                'histEnable', default_histEnable, p.Results.histEnable, @update_histEnable, function_handle.empty(0);...
                'histFaceColor', default_histFaceColor, p.Results.histFaceColor, @update_histFaceColor, function_handle.empty(0);...
                'histEdgeColor', default_histEdgeColor, p.Results.histEdgeColor, @update_histEdgeColor, function_handle.empty(0);...
                'histLineStyle', default_histLineStyle, p.Results.histLineStyle, @update_histLineStyle, function_handle.empty(0);...
                'histLineWidth', default_histLineWidth, p.Results.histLineWidth, @update_histLineWidth, @validate_histLineWidth;...
                'linesColormap', default_linesColormap, p.Results.linesColormap, @update_linesColormap, function_handle.empty(0);...
                'linesLineStyle', default_linesLineStyle, p.Results.linesLineStyle, @update_linesLineStyle, function_handle.empty(0);...
                'linesLineWidth', default_linesLineWidth, p.Results.linesLineWidth, @update_linesLineWidth, @validate_linesLineWidth};
                
            % create table
            obj.paramTable = cell2table(initCell(:,2:end),'RowNames',initCell(:,1),'VariableNames',tableFields);
            
            % initialize other properties
            obj.figUnitsOld = default_figUnits;
            obj.clearData;
            
            % set default values to UI components
            for ii = 1:numel(obj.paramList)
                obj.resetValue(obj.paramList{ii})
            end
        end
        
        %% set.stateManager -----------------------------------------------
        function set.stateManager(obj,sm)
            validateattributes(sm,{'CABLE.UIManagement.UIStateManager'},{'scalar'})
            obj.stateManager = sm;
        end
        
        %% set.h_popupmenuCurrentPlot -------------------------------------
        function set.h_popupmenuCurrentPlot(obj,h)
            validateattributes(h,{'matlab.ui.control.UIControl'},{'scalar'})
            assert(strcmp(h.Style,'popupmenu'),'Expected UIControl object to be a popupmenu')
            obj.h_popupmenuCurrentPlot = h;
        end
        
        %% set.h_pushbuttonClear ------------------------------------------
        function set.h_pushbuttonClear(obj,h)
            validateattributes(h,{'matlab.ui.control.UIControl'},{'scalar'})
            assert(strcmp(h.Style,'pushbutton'),'Expected UIControl object to be a popupmenu')
            obj.h_pushbuttonClear = h;
        end
        
        %% set.h_pushbuttonSave -------------------------------------------
        function set.h_pushbuttonSave(obj,h)
            validateattributes(h,{'matlab.ui.control.UIControl'},{'scalar'})
            assert(strcmp(h.Style,'pushbutton'),'Expected UIControl object to be a popupmenu')
            obj.h_pushbuttonSave = h;
        end
        
        %% get.figExists --------------------------------------------------
        function fe = get.figExists(obj)
            fe = isgraphics(obj.hFig);
        end
        
        %% get.legendExists -----------------------------------------------
        function le = get.legendExists(obj)
            le = isgraphics(obj.hLegend);
        end
        
        %% get.dataName_Uninterpreted -------------------------------------
        function n = get.dataName_Uninterpreted(obj)
            n = obj.dataName;
            % Precede every special character with a '\'
            n = strrep(n,'\','\\'); % Must be first!
            n = strrep(n,'_','\_');
            n = strrep(n,'^','\^');
            n = strrep(n,'{','\{');
            n = strrep(n,'}','\}');
        end
        
        %% get.nIPIs ------------------------------------------------------
        function n = get.nIPIs(obj)
            n = numel(obj.IPIs);
        end
        
        %% get.nGMMs ------------------------------------------------------
        function n = get.nGMMs(obj)
            n = numel(obj.GMMTables);
        end
        
        %% get.binWidth ---------------------------------------------------
        function w = get.binWidth(obj)
            w = 1/(obj.Fs/1000);
        end
        
        %% get.activeModel ------------------------------------------------
        function am = get.activeModel(obj)
            hVal = obj.h_popupmenuCurrentPlot.Value;
            hStr = obj.h_popupmenuCurrentPlot.String{hVal};
            if strcmp(hStr,'N/A')
                am = NaN;
            else
                am = hVal-1;
            end
        end
        
        %% get.scale_PD2Count ---------------------------------------------
        function s = get.scale_PD2Count(obj)
            s = obj.nIPIs*obj.binWidth;
        end
        
        %% get.scale_Count2PD ---------------------------------------------
        function s = get.scale_Count2PD(obj)
            s = 1/(obj.nIPIs*obj.binWidth);
        end
        
        %% setUIHandle ----------------------------------------------------
        % DEFUNCT - use constructor instead
        %{
        function setUIHandle(obj,param,h)
        % Sets "UIHandle" for specified parameter.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParam = ischar(param) && ismember(param,obj.paramList);
            if ~validParam
                error('Invalid parameter name')
            end
            
            % set h to paramTable if it's a valid graphics handle
            if isgraphics(h)
                obj.paramTable.UIHandle(param) = h;
            else
                error('Last argument is not a supported UI object')
            end
            
            % set default value
            obj.resetValue(param);
        end
        %}
        
        %% getUIHandle ----------------------------------------------------
        function h = getUIHandle(obj,params)
        % Gets "UIHandle" for specified parameters.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParams = ismember(params,obj.paramList);
            if ~all(validParams)
                error('Invalid parameter names')
            end
            
            % get
            %if iscell(params)
                h = obj.paramTable.UIHandle(params);
            %else
            %    h = obj.paramTable.UIHandle{params};
            %end
        end
        
        %% getDefault -------------------------------------------------------
        function dval = getDefault(obj,params)
        % Returns the default value(s) of specified parameters.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParams = ismember(params,obj.paramList);
            if ~all(validParams)
                error('Invalid parameter names')
            end
            
            % get
            if iscell(params)
                dval = obj.paramTable.Default(params);
            else
                dval = obj.paramTable.Default{params};
            end
        end
        
        %% resetValue -----------------------------------------------------
        function resetValue(obj,param)
        % Sets the value of a parameter to its default. The default value
        % replaces the current string/value of the parameter's UI object.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParam = ischar(param) && ismember(param,obj.paramList);
            if ~validParam
                error('Invalid parameter name')
            end
            
            % set default based on type
            val = obj.getDefault(param);
            h = obj.getUIHandle(param);
            hType = obj.getUIType(h);
            switch hType
                case 'edit'
                    h.String = setCharData(val);
                case 'popupmenu'
                    h.Value = find(strcmp(val,h.String));
                case 'pushbutton'
                    if isstruct(val)
                        h.UserData = val;
                    else
                        h.BackgroundColor = val;
                    end
                case 'table'
                    % do nothing - this is controlled by other UI
                otherwise
                    error('UI handle is not a recognized type')
            end
            obj.updatePlot(h)
            
            % NESTED FUNCTIONS
            % setCharData .................................................
            function s = setCharData(v)
                if ischar(v) || iscellstr(v)
                    % default is a string or cell array of strings
                    s = v;
                else
                    % default is a number
                    s = num2str(v);
                end
            end
        end
        
        %% getValue -------------------------------------------------------
        function val = getValue(obj,params)
        % Returns the value(s) of specified parameters, interpreted from
        % the UI object strings or values.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParams = ismember(params,obj.paramList);
            if ~all(validParams)
                error('Invalid parameter names')
            end
            
            % get
            if iscell(params)
                nParams = numel(params);
                val = cell(size(params));
                for ii = 1:nParams
                    paramii = params{ii};
                    hii = obj.getUIHandle(paramii);
                    val{ii} = extractParamValue(hii);
                end
            else
                h = obj.getUIHandle(params);
                val = extractParamValue(h);
            end
            
            % NESTED FUNCTIONS 
            % extractParamValue ...........................................
            function v = extractParamValue(h)
                hType = obj.getUIType(h);
                switch hType
                    case 'edit'
                        hVal = h.String;
                        isSingleLine = (h.Max - h.Min) <= 1;
                        if isSingleLine
                            % return char data
                            v = extractCharData(hVal);
                        else
                            % return cell string
                            if isempty(hVal)
                                v = cell.empty(0,1);
                            else
                                v = cellstr(hVal);
                            end
                        end
                        %if isrow(hVal) % other possibility is cellstr
                        %    v = extractCharData(hVal);
                        %else
                        %    v = cellstr(hVal);
                        %end
                    case 'popupmenu'
                        hVal = h.Value;
                        v = h.String{hVal};
                    case 'pushbutton'
                        % check if there's data inside the UserData
                        % property. If there isn't, then value of interest
                        % is background colour.
                        if isempty(h.UserData)
                            v = h.BackgroundColor;
                        else
                            v = h.UserData;
                        end
                    case 'table'
                        v = h.Data;
                    otherwise
                        error('UI handle does not exist or is not a recognized type')
                end
            end
            
            % extractCharData..............................................
            function v = extractCharData(s)
                % check for numeric data
                sSplit = strsplit(s);
                sNum = cellfun(@str2double,sSplit);
                if ~any(isnan(sNum))
                    % confirmed numeric
                    v = sNum;
                else
                    % string
                    v = s;
                end
            end
        end
        
        %% isValid --------------------------------------------------------
        function [validity,errMsg] = isValid(obj,params)
        % Checks if one or more parameters are valid. Returns a logical
        % indicating so, as well as an error message string. The string is
        % empty for valid parameters.
        % If a validation function is not defined, returns true.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParams = ismember(params,obj.paramList);
            if ~all(validParams)
                error('Invalid parameter names')
            end
            
            % check input type
            cellInput = iscell(params);
            
            % check parameter validity
            if ~cellInput
                params = {params};
            end
            nParams = numel(params);            
            validity = false(nParams,1);
            errMsg = cell(nParams,1);
            for ii = 1:nParams
                fii = obj.paramTable.ValidationFunction(params{ii});
                fii = fii{:};
                if isempty(fii);
                    validity(ii) = true;
                    errMsg{ii} = '';
                else
                    try
                        feval(fii,obj);
                        validity(ii) = true;
                        errMsg{ii} = '';
                    catch ME
                        validity(ii) = false;
                        errMsg{ii} = ME.message;
                    end
                end
            end
            
            if ~cellInput
                errMsg = errMsg{:};
            end
        end
        
        %% updatePlot -----------------------------------------------------
        function updatePlot(obj,h)
        % Processes the value of a parameter set within UI component 'h'.
        % Parameter values are first validated, and their UI components are
        % adjusted accordingly (i.e. background colour is white if valid,
        % red otherwise. This should only apply to editboxes).
        % Second, if a plot exists and a parameter value is valid, the plot
        % is updated.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % determine which parameter is controlled by h
            nParams = numel(obj.paramList);
            searching = true;
            m = 1;
            while searching && m <= nParams
                hm = obj.paramTable.UIHandle(m);
                if h == hm
                    searching = false;
                else
                    m = m + 1;
                end
            end
            if searching
                error('UI handle not found')
            end
            param = obj.paramTable.Properties.RowNames{m};

            % check validity
            if ~isempty(obj.paramTable.ValidationFunction{param})
                validParam = obj.isValid(param);
                if validParam
                    h.BackgroundColor = obj.colourValid;
                else
                    h.BackgroundColor = obj.colourInvalid;
                    return
                end
            end
            
            % update plot appearance
            updateFcn = obj.paramTable.UpdateFunction{m};
            if ~isempty(updateFcn)
                feval(updateFcn,obj)
                if obj.figExists
                    obj.syncAxesPosition;
                end
            end
        end
       
        %% setData --------------------------------------------------------
        function setData(obj,dname,ddir,IPIDist,GMData,GMDeltaBICs,sampRate,IPIRange,show)
        % Sets data and creates plot
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % issue warning if there are no IPIs and abort
            if isempty(IPIDist)
                warning('No IPIs to plot!')
                return
            end
        
            % close existing figure
            if obj.figExists
                obj.closeFig;
            end
            
            % set data and create plot
            obj.dataName = dname;
            obj.dataDir = ddir;
            obj.IPIs = IPIDist;
            obj.GMMTables = GMData;
            obj.deltaBICs = GMDeltaBICs;
            obj.Fs = sampRate;
            obj.IPIRange = IPIRange;
            obj.plotVisible = show;
            obj.toggleCurrentPlotMenuState('on');
            obj.stateManager.changeActiveStateValue(obj.h_pushbuttonClear,'on');
            obj.stateManager.changeActiveStateValue(obj.h_pushbuttonSave,'on');
            obj.createPlot;
        end
        
        %% updateCurrentPlot ---------------------------------------------
        function updateCurrentPlot(obj)
        % Adjusts a plot based on existing settings. Use when cycling
        % between models.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            cp = obj.activeModel;
            
            % loop through each model
            for ii = 1:obj.nGMMs
                % initialize model loop variables
                if ii == cp
                    vii = 'on';
                else
                    vii = 'off';
                end
                hLinesii = obj.hLines{ii};
                nClustersii = numel(hLinesii);

                % turn each cluster line on or off
                for jj = 1:nClustersii
                    hLinesii(jj).Visible = vii;
                end
            end
            
            % update relevant things
            obj.update_axesTitleVisible;
            obj.update_legendEnable;
            obj.syncAxesPosition;
        end
        
        %% closeFig -------------------------------------------------------
        function closeFig(obj)
        % Deletes existing figure and removes its data from the object
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.figExists
                delete(obj.hFig)
                obj.clearData;
            end
        end
        
        %% saveFig --------------------------------------------------------
        function saveFig(obj,outDir,plotNums,showWaitBar)
        % Saves plots of an existing figure as image files.
        % A file is generated for each plot specified, and each file type.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % WARNING: be very careful with the waitbar code here, especially 
        % its close request callback. If there are bugs, MATLAB might need
        % to be closed forcefully.
        
            % initialize variables
            if obj.isValid('printResolution')
                pResVal = obj.getValue('printResolution');
            else
                warning('printResolution is invalid. Using default printResolution.')
                pResVal = obj.getDefault('printResolution');
            end
            if ischar(pResVal) && strcmp(pResVal,'screen')
                r = 0;
            else
                r = pResVal;
            end
            pArgs = obj.getValue('printArgs');
            fTypes = obj.getValue('printFileTypes');
            activePlotNum = obj.h_popupmenuCurrentPlot.Value;
            nTypes = numel(fTypes);
            nPlots = numel(plotNums);
            
            % initialize waitbar if specified
            if showWaitBar
                %%% create waitbar figure
                hWaitFig = waitbar(0,'Saving plots...','CreateCancelBtn',@closeWaitBar,...
                    'WindowStyle','modal',...
                    'Visible','off');
                %%% hack the cancel button
                hWaitButton = findobj(hWaitFig.Children,'Style','pushbutton');
                hWaitButton.String = 'OK';
                hWaitButton.Enable = 'off';
                %%% make figure visible
                hWaitFig.Visible = 'on';
                %%% initialize iteration count
                iter = 1;
                nIter = nTypes*nPlots;
            end
            % loop through each file type
            try
                for ii = 1:nTypes
                    fTypeii = fTypes{ii};
                    pArgsii = pArgs{ii};
                    if isempty(pArgsii)
                        pArgsii = {};
                    else
                        pArgsii = strsplit(pArgsii);
                    end

                    % loop through each plot
                    for jj = 1:nPlots
                        plotNumjj = plotNums(jj);

                        % change active plot
                        obj.h_popupmenuCurrentPlot.Value = plotNumjj;
                        obj.updateCurrentPlot;

                        % define filename and path
                        if plotNumjj > 1
                            figNamejj = sprintf('GMM%d',plotNumjj-1);
                        else
                            figNamejj = 'IPIDist';
                        end
                        figPathjj = fullfile(outDir,figNamejj);

                        % save
                        try
                            print(obj.hFig,figPathjj,['-d',fTypeii],['-r',num2str(r)],pArgsii{:})
                        catch ME
                            switch ME.identifier
                                case 'MATLAB:print:InvalidDeviceOption'
                                    warning('Failed to save figure: ''%s'' is not a valid file type')
                                otherwise
                                    warning('Failed to save figure of type ''%s'' with specified options:\n%s\nTrying again without options.',fTypeii,ME.message)
                                    print(obj.hFig,figPathjj,['-d',fTypeii],['-r',num2str(r)])
                            end
                        end
                        
                        % update waitbar if there is one
                        if showWaitBar
                            waitbar(iter/nIter,hWaitFig)
                            iter = iter + 1;
                        end
                    end
                end

                % restore previously active plot
                obj.h_popupmenuCurrentPlot.Value = activePlotNum;
                obj.updateCurrentPlot;
                
                % end waitbar if there is one
                if showWaitBar
                    waitbar(1,hWaitFig,'Saving complete!')
                    hWaitButton.Enable = 'on';
                end
            catch ME
                if showWaitBar
                    delete(hWaitFig)
                end
                rethrow(ME)
            end
            
            % NESTED FUNCTION: WAITBAR CLOSE REQUEST CALLBACK
            % Be careful with this. Unfortunately, the way MATLAB's waitbar
            % is coded, the 'src' variable can vary in this callback. If 
            % the cancel button is pressed, 'src' is the button handle. But 
            % if the window is closed with the X button, then 'src' is the
            % figure handle. Be sure to delete the FIGURE in this callback.
            % Otherwise, this will create a situation where a modal window 
            % cannot be closed, which will require a forceful termination.
            function closeWaitBar(src,edata)
                switch src.Type
                    case 'figure'
                        hf = src;
                        hb = findobj(src.Children,'Style','pushbutton');
                    case 'uicontrol'
                        hf = src.Parent;
                        hb = src;
                end
                if strcmp(hb.Enable,'on')
                    delete(hf)
                end
            end
        end
    end
    
    %% METHODS - PUBLIC STATIC ============================================
    methods (Static)
        %% getUIType ------------------------------------------------------
        function typeStr = getUIType(h)
        % Returns a string indicating the type of a UI object.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            badType = 'unknown';
            hClass = class(h);
            
            % assess type
            switch hClass
                case 'matlab.ui.control.UIControl'
                    typeStr = h.Style;
                case 'matlab.ui.control.Table'
                    typeStr = 'table';
                otherwise
                    typeStr = badType;
            end
        end
    end
    
    %% METHODS - PRIVATE ==================================================
    methods (Access = private)
        %% createPlot -----------------------------------------------------
        function createPlot(obj)
        % The main plotting function.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % initialize variables
            plotIPIRange = [max(0,obj.IPIRange(1)-1),obj.IPIRange(2)];
            obj.hLines = cell(obj.nGMMs,1);
            tStepHighRes = obj.binWidth/4;
            tVec = (0:obj.binWidth:plotIPIRange(2))';
            tVec = tVec(tVec >= plotIPIRange(1));
            binEdges = [tVec;tVec(end)+obj.binWidth] - obj.binWidth/2;
            xPDF = (0:tStepHighRes:(plotIPIRange(2) + tStepHighRes))';
            xPDF = xPDF(xPDF >= plotIPIRange(1));
            
            
            % 1) create figure
            obj.hFig = figure(...
                'Visible','off',...
                'MenuBar','none',...
                'Name',obj.dataName,...
                'NumberTitle','off');
            %obj.hFig = figure(); % FOR DEBUGGING
            obj.hFig.UserData = obj;
            obj.hFig.PaperPositionMode = 'auto';
            obj.hFig.SizeChangedFcn = @CABLE.UIManagement.PlotManager.fig_SizeChangedFcn;
            obj.hFig.CloseRequestFcn = @CABLE.UIManagement.PlotManager.fig_CloseRequestFcn;
            
            
            % 2) create axes (unconfigured)
            obj.hAxesBase = axes('Parent',obj.hFig);
            obj.hAxesCount = axes('Parent',obj.hFig);
            obj.hAxesPD = axes('Parent',obj.hFig);
            obj.hAxesPD.NextPlot = 'add';
            
            
            % 3) create histogram
            %%% This uses a bar graph rather than a Histogram object,
            %%% because bar graphs give more control over appearance.
            IPIHistCounts = histcounts(obj.IPIs,binEdges','Normalization','pdf');
            obj.hHist = bar(tVec,IPIHistCounts,1,'Parent',obj.hAxesPD);
            %obj.hHistIPIDist = histogram(obj.IPIs,binEdges,'Normalization','pdf','Parent',obj.hAxesPD_Hist);
            
            
            % 4) create GM distribution lines
            for ii = 1:obj.nGMMs
                % initialize loop variables
                GMMTableii = obj.GMMTables{ii};
                nClustersii = height(GMMTableii);
                
                % plot lines
                hLinesii = repelem(matlab.graphics.GraphicsPlaceholder,nClustersii,1);
                for jj = 1:nClustersii
                    %%% get PDF data
                    mujj = GMMTableii.mu(jj);
                    sigmajj = GMMTableii.sigma(jj);
                    pjj = GMMTableii.p(jj);
                    gDistjj = makedist('Normal',mujj,sigmajj);
                    yPDFjj = gDistjj.pdf(xPDF)*pjj;
                    
                    %%% plot
                    hLinesii(jj) = line(xPDF,yPDFjj,'Parent',obj.hAxesPD);
                end
                
                % save handles
                obj.hLines{ii} = hLinesii;
            end
            
            
            % 5) save automatic X- and Y- scales
            obj.yMaxPD_auto = obj.hAxesPD.YLim(2);
            obj.setAutoXRange();
            
            
            % 6) set permanent axes properties and links
            %%% Base
            obj.hAxesBase.YTick = [];
            obj.hAxesBase.XLimMode = 'manual';
            
            %%% Count
            obj.hAxesCount.Color = 'none';
            obj.hAxesCount.XColor = 'none';
            obj.hAxesCount.Box = 'off';
            obj.hAxesCount.YLimMode = 'manual';
            
            %%% PD
            obj.hAxesPD.Color = 'none';
            obj.hAxesPD.XColor = 'none';
            obj.hAxesPD.Box = 'off';
            obj.hAxesPD.YLimMode = 'manual';
            
            %%% links
            %%% Note that this resets the X (and Y?) limits of everything to 1.
            obj.hLinkX = linkprop([obj.hAxesBase;obj.hAxesCount;obj.hAxesPD],'XLim');
            
            %%% initialize X-axis to be infinite (I don't know why this
            %%% works, but it does). This is to ensure each element can be
            %%% initialized seperately without conflict (for example, it's
            %%% not possible to set XLim(1) = 2 when XLim(2) == 1).
            obj.hAxesBase.XLim = [-Inf,Inf];
            
            
            % 7) set plot appearance and dimensions
            if obj.nGMMs > 0
                obj.h_popupmenuCurrentPlot.Value = 2;
            else
                obj.h_popupmenuCurrentPlot.Value = 1;
            end
            obj.updateCurrentPlot;
            obj.update_figUnits;
            obj.update_figWidth;
            obj.update_figHeight;
            %obj.update_printResolution;
            obj.update_renderer;
            obj.update_printFileTypes;
            obj.update_axesBoxVisible;
            obj.update_axesTitleVisible;
            obj.update_axesXLabelsVisible;
            obj.update_axesYLabelsVisible_Count; 
            obj.update_axesYLabelsVisible_PD; 
            obj.update_axesXMin;
            obj.update_axesXMax;
            obj.update_axesYMax_PD; % only need one
            obj.update_axesTickDir;
            obj.update_axesTickLength;
            obj.update_axesTickLength;
            obj.update_axesLineWidth;
            obj.update_axesFont;
            obj.update_axesLabelFontSizeMultiplier;
            obj.update_axesTitleFontSizeMultiplier;
            obj.update_axesTitleFontWeight;
            obj.update_legendEnable;
            obj.update_legendBoxVisible;
            obj.update_legendLineWidth;
            obj.update_legendFont;
            obj.update_histEnable;
            obj.update_histFaceColor;
            obj.update_histEdgeColor;
            obj.update_histLineStyle;
            obj.update_histLineWidth;
            obj.update_linesColormap;
            obj.update_linesLineStyle;
            obj.update_linesLineWidth;
            obj.syncAxesPosition;
            
            % make visible if specified
            if obj.plotVisible
                obj.hFig.Visible = 'on';
            end
        end
        
        %% toggleCurrentPlotMenuState -------------------------------------
        function toggleCurrentPlotMenuState(obj,state)
        % Switches the 'currentPlot' popupmenu on or off.
        % Data must exist for it to be on.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            h = obj.h_popupmenuCurrentPlot;
            switch state
                case 'on'
                    nOptions = obj.nGMMs + 1;
                    hStr = cell(nOptions,1);
                    hStr{1,1} = 'IPI Distribution';
                    charDelta = char(916); % 916 is the Unicode number for Greek capital delta
                    for ii = 1:obj.nGMMs
                        hStr{ii+1,1} = sprintf('GMM %d (%sBIC = %.2f)',ii,charDelta,obj.deltaBICs(ii));
                    end
                    h.String = hStr;
                    h.Value = 1;
                    obj.stateManager.changeActiveStateValue(h,'on');
                    %h.Enable = 'on';
                case 'off'
                    h.String = 'N/A';
                    h.Value = 1;
                    obj.stateManager.changeActiveStateValue(h,'off');
                    %h.Enable = 'off';
                otherwise
                    error('Unrecognized state')
            end
        end
        
        %% updatePaperDimensions ------------------------------------------
        % DEFUNCT
        %{
        function updatePaperDimensions(obj)
        % Updates the figure's paper dimensions. Call this after figure
        % display dimensions change.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            units = obj.hFig.Units;
            switch units
                case 'pixels'
                    obj.hFig.PaperUnits = 'inches';
                    if obj.isValid('printResolution')
                        fcn = @getValue;
                    else
                        fcn = @getDefault;
                    end
                    printResEntry = feval(fcn,obj,'printResolution');
                    if printResEntry == 0
                        r = get(groot,'ScreenPixelsPerInch');
                    else
                        r = printResEntry;
                    end
                    obj.hFig.PaperPosition = (obj.hFig.Position/r) .* [0 0 1 1];
                otherwise
                    obj.hFig.PaperUnits = units;
                    obj.hFig.PaperPosition = obj.hFig.Position .* [0 0 1 1];
            end
        end
        %}
        
        %% syncAxesPosition -----------------------------------------------
        function syncAxesPosition(obj)
        % Synchronizes the Position properties of all axes in the figure to
        % the largest possible position that will fit everything: title,
        % X-label, left Y-label, and right Y-label.
        % Assumes axes units are Normalized.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % initialize variables
            hAxesAll = [obj.hAxesBase;obj.hAxesCount;obj.hAxesPD];
            nAxes = numel(hAxesAll);
            
            % ensure OuterPosition is OK
            posOut = [0,0,1,1];
            for ii = 1:nAxes
                hAxesAll(ii).OuterPosition = posOut;
            end
            drawnow
            
            % find best axis position.
            % Need valid OuterPosition for this.
            %%% get matrix of current positions
            posCell = cell(nAxes,1);
            for ii = 1:nAxes
                posCell{ii} = hAxesAll(ii).Position;
            end
            posMat = cell2mat(posCell);
            %%% get best dimensions
            xLeft = max(posMat(:,1));
            xRight = min(posMat(:,1) + posMat(:,3));
            yBottom = max(posMat(:,2));
            yTop = min(posMat(:,4) + posMat(:,2));
            posMin = [xLeft,yBottom,xRight-xLeft,yTop-yBottom];
            
            % assign new position
            for ii = 1:nAxes
                hAxesAll(ii).Position = posMin;
            end
        end
        
        %% clearData ------------------------------------------------------
        function clearData(obj)
        % Resets all data variables.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                obj.dataName = '';
                obj.dataDir = '';
                obj.IPIs = double.empty(0,1);
                obj.GMMTables = cell.empty(0,1);
                obj.deltaBICs = double.empty(0,1);
                obj.Fs = NaN;
                obj.IPIRange = [NaN,NaN];
                obj.plotVisible = NaN;
                obj.xMin_auto = NaN;
                obj.xMax_auto = NaN;
                obj.yMaxPD_auto = NaN;
                obj.hFig = matlab.graphics.GraphicsPlaceholder;
                obj.hAxesBase = matlab.graphics.GraphicsPlaceholder;
                obj.hAxesCount = matlab.graphics.GraphicsPlaceholder;
                obj.hAxesPD = matlab.graphics.GraphicsPlaceholder;
                obj.hLegend = matlab.graphics.GraphicsPlaceholder;
                obj.hHist = matlab.graphics.GraphicsPlaceholder;
                obj.hLines = cell.empty(0,1);
                obj.hLinkX = matlab.graphics.GraphicsPlaceholder;
                obj.toggleCurrentPlotMenuState('off')
                obj.stateManager.changeActiveStateValue(obj.h_pushbuttonClear,'off')
                obj.stateManager.changeActiveStateValue(obj.h_pushbuttonSave,'off')
                %obj.h_pushbuttonClear.Enable = 'off';
                %obj.h_pushbuttonSave.Enable = 'off';
        end
        
        %% setAutoXRange --------------------------------------------------
        function setAutoXRange(obj)
        % Determines an appropriate display range for the X-axis based on
        % the range spanned by the source data.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if isempty(obj.IPIs)
                obj.xMin_auto = obj.IPIRange(1);
                obj.xMax_auto = obj.IPIRange(2);
            else
                % initialize variables
                xMult = 10;
                xDiv = 2;
                bufferMultLeft = 0.25;
                bufferMultRight = 1;
                
                % get IPI range and derive buffer values
                IPIMin = min(obj.IPIs);
                IPIMax = max(obj.IPIs);
                IPIDiff = IPIMax - IPIMin;
                bufferLeft = IPIDiff*bufferMultLeft;
                bufferRight = IPIDiff*bufferMultRight;
                xMin = IPIMin - bufferLeft;
                xMin = (xDiv*floor((xMin*xMult)/xDiv))/xMult;
                xMax = IPIMax + bufferRight;
                xMax = (xDiv*ceil((xMax*xMult)/xDiv))/xMult;
                
                % set limits
                obj.xMin_auto = xMin;
                obj.xMax_auto = xMax;
                
                % old code follows
                %{
                % time resolution
                tRes = 1/(obj.Fs/1000);
                
                % get full data range
                IPIMin = min(obj.IPIs);
                IPIMax = max(obj.IPIs);
                
                % set limits
                obj.xMin_auto = floor(IPIMin - tRes);
                obj.xMax_auto = ceil(IPIMax + tRes);
                %}
            end
        end
        
        %% getXRangeEnumValue ---------------------------------------------
        function v = getXRangeEnumValue(obj,xLimit,enum)
        % Returns the value for XMin or XMax enumerations ('full' or
        % 'auto').
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch xLimit
                case 'min'
                    valAuto = obj.xMin_auto;
                    valFull = obj.IPIRange(1);
                case 'max'
                    valAuto = obj.xMax_auto;
                    valFull = obj.IPIRange(2);
                otherwise
                    error('Unrecognized limit')
            end
            
            switch enum
                case 'auto'
                    v = valAuto;
                case 'full'
                    v = valFull;
                otherwise
                    error('Unrecognized enumeration')
            end
        end
    end
    
    %% METHODS - PRIVATE (UpdateFunctions) ================================
    methods
        %% update_figUnits ------------------------------------------------
        function update_figUnits(obj)
            unitsOld = obj.figUnitsOld;
            unitsNew = obj.getValue('figUnits');
            
            % update width and height handles, if those values exist
            hWidth = obj.getUIHandle('figWidth');
            hHeight = obj.getUIHandle('figHeight');
            if ~isempty(hWidth.String) && ~isempty(hHeight.String)
                %if obj.figExists
                    % set new units
                %    obj.hFig.Units = unitsNew;
                %end

                    % determine new Width and Height values
                    %posNew = obj.hFig.Position;
                    %widthNew = posNew(3);
                    %heightNew = posNew(4);
                %else
                % recalculate new Width and Height values manually
                inch2cm = 2.54;
                cm2inch = 1/inch2cm;
                widthOld = obj.getValue('figWidth');
                heightOld = obj.getValue('figHeight');

                %%% start by converting to inches
                switch unitsOld
                    case 'pixels'
                        widthInches = widthOld/get(groot,'ScreenPixelsPerInch');
                        heightInches = heightOld/get(groot,'ScreenPixelsPerInch');
                    case 'centimeters'
                        widthInches = widthOld*cm2inch;
                        heightInches = heightOld*cm2inch;
                    case 'inches'
                        widthInches = widthOld;
                        heightInches = heightOld;
                    otherwise
                        error('Unrecognized units')
                end

                %%% convert to new units
                switch unitsNew
                    case 'pixels'
                        widthNew = round(widthInches*get(groot,'ScreenPixelsPerInch'));
                        heightNew = round(heightInches*get(groot,'ScreenPixelsPerInch'));
                    case 'centimeters'
                        widthNew = widthInches*inch2cm;
                        heightNew = heightInches*inch2cm;
                    case 'inches'
                        widthNew = widthInches;
                        heightNew = heightInches;
                    otherwise
                        error('Unrecognized units')
                end
                %end

                % set values to UI components and update plot
                hWidth.String = num2str(widthNew);
                hHeight.String = num2str(heightNew);
                if obj.figExists
                    obj.hFig.Units = unitsNew;
                    obj.update_figWidth;
                    obj.update_figHeight;
                end
            end
            
            % if pixel units, force print resolution to screen. Otherwise,
            % make sure it's active.
            hPrintRes = obj.getUIHandle('printResolution');
            if strcmp(unitsNew,'pixels')
                hPrintRes.String = 'screen';
                obj.stateManager.changeActiveStateValue(hPrintRes,'off');
                %hPrintRes.Enable = 'off';
            else
                obj.stateManager.changeActiveStateValue(hPrintRes,'on');
                %hPrintRes.Enable = 'on';
            end
            
            % update figUnitsOld
            obj.figUnitsOld = unitsNew;
        end
        
        %% update_figWidth ------------------------------------------------
        function update_figWidth(obj)
            if obj.figExists
                param = 'figWidth';
                if obj.isValid(param)
                    fcn = @getValue;
                else
                    fcn = @getDefault;
                end
                w = feval(fcn,obj,param);
                obj.hFig.Position(3) = w;
            end
        end
        
        %% update_figHeight ------------------------------------------------
        function update_figHeight(obj)
            if obj.figExists
                param = 'figHeight';
                if obj.isValid(param)
                    fcn = @getValue;
                else
                    fcn = @getDefault;
                end
                h = feval(fcn,obj,param);
                obj.hFig.Position(4) = h;
            end
        end
        
        %% update_printResolution -----------------------------------------
        % DEFUNCT
        %{
        function update_printResolution(obj)
            if obj.figExists
                obj.updatePaperDimensions;
            end
        end
        %}
        
        %% update_renderer ------------------------------------------------
        function update_renderer(obj)
            if obj.figExists
                obj.hFig.Renderer = obj.getValue('renderer');
            end
        end
        
        %% update_printFileTypes ------------------------------------------
        function update_printFileTypes(obj)
            fTypes = obj.getValue('printFileTypes');
            [nFileTypes,~] = size(fTypes);
            %fTypeCell = cellstr(obj.getValue('printFileTypes'));
            %nFileTypes = numel(fTypeCell);
            
            % edit number of rows in printArgs table
            hPrintArgs = obj.getUIHandle('printArgs');
            printArgData = hPrintArgs.Data;
            nPrintArgRowsOld = numel(printArgData);
            rowDiff = nFileTypes - nPrintArgRowsOld;
            if rowDiff > 0
                % add rows
                hPrintArgs.Data = [printArgData;repmat({''},rowDiff,1)];
            else
                % keep same or remove rows
                hPrintArgs.Data = printArgData(1:nFileTypes,1);
            end
            
            % edit column size based on number of rows
            if nFileTypes < 3
                hPrintArgs.ColumnWidth = {88};
            else
                hPrintArgs.ColumnWidth = {71};
            end
        end
        
        %% update_axesBoxVisible ------------------------------------------
        function update_axesBoxVisible(obj)
            if obj.figExists
                obj.hAxesBase.Box = obj.getValue('axesBoxVisible');
            end
        end
        
        %% update_axesTitleVisible ----------------------------------------
        function update_axesTitleVisible(obj)
            if obj.figExists
                titState = obj.getValue('axesTitleVisible');
                switch titState
                    case 'on'
                        cp = obj.activeModel;
                        titBase = obj.dataName_Uninterpreted;
                        if cp > 0
                            titAppend = sprintf(' - GMM#%d (\\DeltaBIC = %.2f)',cp,obj.deltaBICs(cp));
                        else
                            titAppend = ' - IPI Distribution';
                        end
                        %tit = [titBase,titAppend];
                        tit = [titBase,titAppend,sprintf('\n')]; % TEST
                        title(obj.hAxesPD,tit)
                    case 'off'
                        title(obj.hAxesPD,'');
                    otherwise
                        error('Unrecognized value')
                end
            end
        end
        
        %% update_axesXLabelsVisible --------------------------------------
        function update_axesXLabelsVisible(obj)
            if obj.figExists
                labState = obj.getValue('axesXLabelsVisible');
                switch labState
                    case 'on'
                        % enable X ticks and label
                        obj.hAxesBase.XTickMode = 'auto';
                        xlabel(obj.hAxesBase,'IPI (ms)')
                    case 'off'
                        % remove X ticks and axis label
                        obj.hAxesBase.XTick = [];
                        xlabel(obj.hAxesBase,'')
                    otherwise
                        error('Unrecognized value')
                end
            end
        end
        
        %% update_axesYLabelsVisible_Count --------------------------------
        function update_axesYLabelsVisible_Count(obj)
            if obj.figExists
                labState = obj.getValue('axesYLabelsVisible_Count');
                switch labState
                    case 'on'
                        % enable Y ticks and label
                        obj.hAxesCount.YTickMode = 'auto';
                        ylabel(obj.hAxesCount,'Count')
                        % Set location of PD axis to the right
                        obj.hAxesPD.YAxisLocation = 'right';
                    case 'off'
                        % remove Y ticks and axis label
                        obj.hAxesCount.YTick = [];
                        ylabel(obj.hAxesCount,'')
                        % Set location of PD axis to the left
                        obj.hAxesPD.YAxisLocation = 'left';
                    otherwise
                        error('Unrecognized value')
                end
            end
        end
        
        %% update_axesYLabelsVisible_PD -----------------------------------
        function update_axesYLabelsVisible_PD(obj)
            if obj.figExists
                labState = obj.getValue('axesYLabelsVisible_PD');
                switch labState
                    case 'on'
                        % enable Y ticks and label
                        obj.hAxesPD.YTickMode = 'auto';
                        ylabel(obj.hAxesPD,'Probability Density')
                    case 'off'
                        % remove Y ticks and axis label
                        obj.hAxesPD.YTick = [];
                        ylabel(obj.hAxesPD,'')
                    otherwise
                        error('Unrecognized value')
                end
            end
        end
        
        %% update_axesXMin ------------------------------------------------
        function update_axesXMin(obj)
            param = 'axesXMin';
            if obj.isValid(param)
                fcn = @getValue;
            else
                fcn = @getDefault;
            end
            xMinEntry = feval(fcn,obj,param);
            h_axesXMax = obj.getUIHandle('axesXMax');
            updateXMax = false;

            % if entry is a string, set appropriate value
            if ischar(xMinEntry)
                xMinVal = obj.getXRangeEnumValue('min',xMinEntry);

                % set xMax to be the same (auto/full)
                if ~strcmp(xMinEntry,h_axesXMax.String)
                    h_axesXMax.String = xMinEntry;
                    updateXMax = true;
                end
            else
                xMinVal = xMinEntry;

                % set numeric string entry for xMax, if it's char 
                xMaxEntry = obj.getValue('axesXMax');
                if ischar(xMaxEntry)
                    h_axesXMax.String = obj.getXRangeEnumValue('max',xMaxEntry);
                end
                
                % reassess xMax, if it's marked as invalid
                if all(h_axesXMax.BackgroundColor == obj.colourInvalid);
                    updateXMax = true;
                end
            end
            
            if obj.figExists
                obj.hAxesBase.XLim(1) = xMinVal;
            end
            if updateXMax
                obj.updatePlot(h_axesXMax)
            end
        end
        
        %% update_axesXMax ------------------------------------------------
        function update_axesXMax(obj)
            param = 'axesXMax';
            if obj.isValid(param)
                fcn = @getValue;
            else
                fcn = @getDefault;
            end
            xMaxEntry = feval(fcn,obj,param);
            h_axesXMin = obj.getUIHandle('axesXMin');
            updateXMin = false;

            % if entry is a string, set appropriate value
            if ischar(xMaxEntry)
                xMaxVal = obj.getXRangeEnumValue('max',xMaxEntry);

                % set xMin to be the same (auto/full)
                if ~strcmp(xMaxEntry,h_axesXMin.String)
                    h_axesXMin.String = xMaxEntry;
                    updateXMin = true;
                end
            else
                xMaxVal = xMaxEntry;

                % set numeric string entry for xMin, if it's char 
                xMinEntry = obj.getValue('axesXMin');
                if ischar(xMinEntry)
                    h_axesXMin.String = obj.getXRangeEnumValue('min',xMinEntry);
                end
                
                % reassess xMin, if it's marked as invalid
                if all(h_axesXMin.BackgroundColor == obj.colourInvalid);
                    updateXMin = true;
                end
            end
            
            if obj.figExists
                obj.hAxesBase.XLim(2) = xMaxVal;
            end
            if updateXMin
                obj.updatePlot(h_axesXMin)
            end
        end
        
        %% update_axesYMax_Count ------------------------------------------
        function update_axesYMax_Count(obj)
            param = 'axesYMax_Count';
            if obj.isValid(param)
                fcn = @getValue;
            else
                fcn = @getDefault;
            end
            yMaxEntry = feval(fcn,obj,param);
            
            % if set to 'auto', use auto range.
            if ischar(yMaxEntry) && strcmp(yMaxEntry,'auto')
                yMaxVal_Count = obj.yMaxPD_auto * obj.scale_PD2Count;
                yMaxVal_PD = obj.yMaxPD_auto;
                yMaxStr_PD = 'auto';
            else
                yMaxVal_Count = yMaxEntry;
                yMaxVal_PD = yMaxVal_Count * obj.scale_Count2PD;
                yMaxStr_PD = num2str(yMaxVal_PD);
            end
            
            % set new string for YMax PD, and give it the valid colour
            hYMaxPD = obj.getUIHandle('axesYMax_PD');
            hYMaxPD.String = yMaxStr_PD;
            hYMaxPD.BackgroundColor = obj.colourValid;
            
            % update plot
            if obj.figExists
                obj.hAxesCount.YLim(2) = yMaxVal_Count;
                obj.hAxesPD.YLim(2) = yMaxVal_PD;
            end
        end
        
        %% update_axesYMax_PD ---------------------------------------------
        function update_axesYMax_PD(obj)
            param = 'axesYMax_PD';
            if obj.isValid(param)
                fcn = @getValue;
            else
                fcn = @getDefault;
            end
            yMaxEntry = feval(fcn,obj,param);
            
            % if set to 'auto', use auto range.
            if ischar(yMaxEntry) && strcmp(yMaxEntry,'auto')
                yMaxVal_PD = obj.yMaxPD_auto;
                yMaxVal_Count = obj.yMaxPD_auto * obj.scale_PD2Count;
                yMaxStr_Count = 'auto';
            else
                yMaxVal_PD = yMaxEntry;
                yMaxVal_Count = yMaxVal_PD * obj.scale_PD2Count;
                yMaxStr_Count = num2str(yMaxVal_Count);
            end
            
            % set new string for YMax Count
            hYMaxCount = obj.getUIHandle('axesYMax_Count');
            hYMaxCount.String = yMaxStr_Count;
            hYMaxCount.BackgroundColor = obj.colourValid;
            
            % update plot
            if obj.figExists
                obj.hAxesPD.YLim(2) = yMaxVal_PD;
                obj.hAxesCount.YLim(2) = yMaxVal_Count;
            end
        end
        
        %% update_axesTickDir ---------------------------------------------
        function update_axesTickDir(obj)
            if obj.figExists
                tickDirVal = obj.getValue('axesTickDir');
                hAxesAll = [obj.hAxesBase,obj.hAxesCount,obj.hAxesPD];
                nAxesAll = numel(hAxesAll);
                for ii = 1:nAxesAll
                    hAxesAll(ii).TickDir = tickDirVal;
                end
            end
        end
        
        %% update_axesTickLength ------------------------------------------
        function update_axesTickLength(obj)
            if obj.figExists
                param = 'axesTickLength';
                if obj.isValid(param)
                    fcn = @getValue;
                else
                    fcn = @getDefault;
                end
                tickLengthVal = feval(fcn,obj,param);
                
                hAxesAll = [obj.hAxesBase,obj.hAxesCount,obj.hAxesPD];
                nAxesAll = numel(hAxesAll);
                for ii = 1:nAxesAll
                    hAxesAll(ii).TickLength(1) = tickLengthVal;
                end
            end
        end
        
        %% update_axesLineWidth -------------------------------------------
        function update_axesLineWidth(obj)
            if obj.figExists
                param = 'axesLineWidth';
                if obj.isValid(param)
                    fcn = @getValue;
                else
                    fcn = @getDefault;
                end
                lineWidthVal = feval(fcn,obj,param);

                hAxesAll = [obj.hAxesBase,obj.hAxesCount,obj.hAxesPD];
                nAxesAll = numel(hAxesAll);
                for ii = 1:nAxesAll
                    hAxesAll(ii).LineWidth = lineWidthVal;
                end
            end
        end
        
        %% update_axesFont ------------------------------------------------
        function update_axesFont(obj)
            if obj.figExists
                fontVal = obj.getValue('axesFont');
                hAxesAll = [obj.hAxesBase,obj.hAxesCount,obj.hAxesPD];
                nAxesAll = numel(hAxesAll);
                for ii = 1:nAxesAll
                    hAxesAll(ii).FontName = fontVal.FontName;
                    hAxesAll(ii).FontUnits = fontVal.FontUnits;
                    hAxesAll(ii).FontSize = fontVal.FontSize;
                    hAxesAll(ii).FontWeight = fontVal.FontWeight;
                    hAxesAll(ii).FontAngle = fontVal.FontAngle;
                end
            end
        end
        
        %% update_axesLabelFontSizeMultiplier -----------------------------
        function update_axesLabelFontSizeMultiplier(obj)
            if obj.figExists
                param = 'axesLabelFontSizeMultiplier';
                if obj.isValid(param)
                    fcn = @getValue;
                else
                    fcn = @getDefault;
                end
                fsmVal = feval(fcn,obj,param);
                
                hAxesAll = [obj.hAxesBase,obj.hAxesCount,obj.hAxesPD];
                nAxesAll = numel(hAxesAll);
                for ii = 1:nAxesAll
                    hAxesAll(ii).LabelFontSizeMultiplier = fsmVal;
                end
            end
        end
        
        %% update_axesTitleFontSizeMultiplier -----------------------------
        function update_axesTitleFontSizeMultiplier(obj)
            if obj.figExists
                param = 'axesTitleFontSizeMultiplier';
                if obj.isValid(param)
                    fcn = @getValue;
                else
                    fcn = @getDefault;
                end
                fsmVal = feval(fcn,obj,param);

                hAxesAll = [obj.hAxesBase,obj.hAxesCount,obj.hAxesPD];
                nAxesAll = numel(hAxesAll);
                for ii = 1:nAxesAll
                    hAxesAll(ii).TitleFontSizeMultiplier = fsmVal;
                end
            end
        end
        
        %% update_axesTitleFontWeight -------------------------------------
        function update_axesTitleFontWeight(obj)
            if obj.figExists
                fwVal = obj.getValue('axesTitleFontWeight');
                hAxesAll = [obj.hAxesBase,obj.hAxesCount,obj.hAxesPD];
                nAxesAll = numel(hAxesAll);
                for ii = 1:nAxesAll
                    hAxesAll(ii).TitleFontWeight = fwVal;
                end
            end
        end
        
        %% update_legendEnable --------------------------------------------
        function update_legendEnable(obj)
            if obj.figExists
                en = obj.getValue('legendEnable');
                cp = obj.activeModel;
                if obj.legendExists
                    delete(obj.hLegend)
                end

                % create new legend if specified
                if strcmp(en,'on') && cp > 0
                    GMMTable = obj.GMMTables{cp};
                    hLines_AddLegendEntries = obj.hLines{cp};
                    nClusters = numel(hLines_AddLegendEntries);
                    legendEntries = cell(nClusters,1);
                    for ii = 1:nClusters
                        muii = GMMTable.mu(ii);
                        sigmaii = GMMTable.sigma(ii);
                        legendEntries{ii} = sprintf('Whale %d: IPI = %.2f \\pm %.2f ms',ii,muii,sigmaii);
                    end

                    % create legend
                    obj.hLegend = legend(obj.hAxesPD,hLines_AddLegendEntries,legendEntries);
                    obj.hLegend.Color = [1 1 1];
                    obj.update_legendBoxVisible;
                    obj.update_legendFont;
                    obj.update_legendLineWidth;
                end
            end
        end
        
        %% update_legendBoxVisible ----------------------------------------
        function update_legendBoxVisible(obj)
            if obj.legendExists
                obj.hLegend.Box = obj.getValue('legendBoxVisible');
            end
        end
        
        %% update_legendLineWidth -----------------------------------------
        function update_legendLineWidth(obj)
            if obj.legendExists
                param = 'legendLineWidth';
                if obj.isValid(param)
                    fcn = @getValue;
                else
                    fcn = @getDefault;
                end
                lineWidthVal = feval(fcn,obj,param);
                obj.hLegend.LineWidth = lineWidthVal;
            end
        end
        
        %% update_legendFont ----------------------------------------------
        function update_legendFont(obj)
            if obj.legendExists
                fontVal = obj.getValue('legendFont');
                obj.hLegend.FontName = fontVal.FontName;
                obj.hLegend.FontUnits = fontVal.FontUnits;
                obj.hLegend.FontSize = fontVal.FontSize;
                obj.hLegend.FontWeight = fontVal.FontWeight;
                obj.hLegend.FontAngle = fontVal.FontAngle;
            end
        end
        
        %% update_histEnable ----------------------------------------------
        function update_histEnable(obj)
            if obj.figExists
                obj.hHist.Visible = obj.getValue('histEnable');
            end
        end
        
        %% update_histFaceColor -------------------------------------------
        function update_histFaceColor(obj)
            if obj.figExists
                obj.hHist.FaceColor = obj.getValue('histFaceColor');
            end
        end
        
        %% update_histEdgeColor -------------------------------------------
        function update_histEdgeColor(obj)
            if obj.figExists
                obj.hHist.EdgeColor = obj.getValue('histEdgeColor');
            end
        end
        
        %% update_histLineStyle -------------------------------------------
        function update_histLineStyle(obj)
            if obj.figExists
                lstEntry = obj.getValue('histLineStyle');
                switch lstEntry
                    case 'solid'
                        lstVal = '-';
                    case 'dashed'
                        lstVal = '--';
                    case 'dotted'
                        lstVal = ':';
                    case 'dash-dotted'
                        lstVal = '-.';
                    otherwise
                        error('Unrecognized line style')
                end
                obj.hHist.LineStyle = lstVal;
            end
        end
        
        %% update_histLineWidth -------------------------------------------
        function update_histLineWidth(obj)
            if obj.figExists
                param = 'histLineWidth';
                if obj.isValid(param)
                    fcn = @getValue;
                else
                    fcn = @getDefault;
                end
                lineWidthVal = feval(fcn,obj,param);
                obj.hHist.LineWidth = lineWidthVal;
            end
        end
        
        %% update_linesColormap -------------------------------------------
        function update_linesColormap(obj)
            if obj.figExists
                cm = obj.getValue('linesColormap');

                % test colourmap to decide if last colour should be omitted (if
                % it's white)
                cmValTest = feval(cm,2);
                if all(cmValTest(2,:) == [1 1 1])
                    nExtra = 1;
                else
                    nExtra = 0;
                end

                % assign colours
                for ii = 1:obj.nGMMs
                    hLinesii = obj.hLines{ii};
                    nClustersii = numel(hLinesii);
                    colMatii = feval(cm,nClustersii+nExtra);

                    for jj = 1:nClustersii
                        hLinesii(jj).Color = colMatii(jj,:);
                    end
                end
            end
        end
        
        %% update_linesLineStyle -------------------------------------------
        function update_linesLineStyle(obj)
            if obj.figExists
                lstEntry = obj.getValue('linesLineStyle');
                switch lstEntry
                    case 'solid'
                        lstVal = '-';
                    case 'dashed'
                        lstVal = '--';
                    case 'dotted'
                        lstVal = ':';
                    case 'dash-dotted'
                        lstVal = '-.';
                    otherwise
                        error('Unrecognized line style')
                end

                for ii = 1:obj.nGMMs
                    hLinesii = obj.hLines{ii};
                    nClustersii = numel(hLinesii);
                    for jj = 1:nClustersii
                        hLinesii(jj).LineStyle = lstVal;
                    end
                end
            end
        end
        
        %% update_linesLineWidth -------------------------------------------
        function update_linesLineWidth(obj)
            if obj.figExists
                param = 'linesLineWidth';
                if obj.isValid(param)
                    fcn = @getValue;
                else
                    fcn = @getDefault;
                end
                lineWidthVal = feval(fcn,obj,param);

                for ii = 1:obj.nGMMs
                    hLinesii = obj.hLines{ii};
                    nClustersii = numel(hLinesii);
                    for jj = 1:nClustersii
                        hLinesii(jj).LineWidth = lineWidthVal;
                    end
                end
            end
        end
    end
    
    %% METHODS - PRIVATE (ValidationFunctions) ============================
    methods (Access = private)
        %% validate_figWidth ----------------------------------------------
        function validate_figWidth(obj)
            val = obj.getValue('figWidth');
            validateattributes(val,{'numeric'},{'scalar','positive'})
        end
        
        %% validate_figHeight -------------------------------------------------
        function validate_figHeight(obj)
            val = obj.getValue('figHeight');
            validateattributes(val,{'numeric'},{'scalar','positive'})
        end
        
        %% validate_printResolution ----------------------------------------------
        function validate_printResolution(obj)
            val = obj.getValue('printResolution');
            try
                assert(strcmp(val,'screen'))
            catch
                validateattributes(val,{'numeric'},{'scalar','integer','nonnegative'})
            end
        end
        
        %% validate_axesXMin ----------------------------------------------
        function validate_axesXMin(obj)
            val = obj.getValue('axesXMin');
            try
                s = validatestring(val,{'auto','full'});
                assert(strcmp(s,val))
            catch
                xMaxEntry = obj.getValue('axesXMax');
                if ischar(xMaxEntry)
                    xMax = obj.getXRangeEnumValue('max',xMaxEntry);
                else
                    xMax = xMaxEntry;
                end
                assert(~isnan(xMax),'xMax is undefined')
                validateattributes(val,{'numeric'},{'scalar','nonnegative','<',xMax})
            end
        end
        
        %% validate_axesXMax ----------------------------------------------
        function validate_axesXMax(obj)
            val = obj.getValue('axesXMax');
            try
                s = validatestring(val,{'auto','full'});
                assert(strcmp(s,val))
            catch
                xMinEntry = obj.getValue('axesXMin');
                if ischar(xMinEntry)
                    xMin = obj.getXRangeEnumValue('min',xMinEntry);
                else
                    xMin = xMinEntry;
                end
                assert(~isnan(xMin),'xMin is undefined')
                validateattributes(val,{'numeric'},{'scalar','nonnegative','>',xMin})
            end
        end
        
        %% validate_axesYMax_Count ----------------------------------------
        function validate_axesYMax_Count(obj)
            val = obj.getValue('axesYMax_Count');
            try
                validateattributes(val,{'numeric'},{'scalar','positive'})
            catch
                assert(strcmp(val,'auto'));
            end
        end
        
        %% validate_axesYMax_PD -------------------------------------------
        function validate_axesYMax_PD(obj)
            val = obj.getValue('axesYMax_PD');
            try
                validateattributes(val,{'numeric'},{'scalar','positive'})
            catch
                assert(strcmp(val,'auto'));
            end
        end
        
        %% validate_axesTickLength ----------------------------------------------
        function validate_axesTickLength(obj)
            val = obj.getValue('axesTickLength');
            validateattributes(val,{'numeric'},{'scalar','nonnegative'})
        end
        
        %% validate_axesLineWidth ----------------------------------------------
        function validate_axesLineWidth(obj)
            val = obj.getValue('axesLineWidth');
            validateattributes(val,{'numeric'},{'scalar','positive'})
        end
        
        %% validate_axesLabelFontSizeMultiplier ----------------------------------------------
        function validate_axesLabelFontSizeMultiplier(obj)
            val = obj.getValue('axesLabelFontSizeMultiplier');
            validateattributes(val,{'numeric'},{'positive'})
        end
        
        %% validate_axesTitleFontSizeMultiplier ----------------------------------------------
        function validate_axesTitleFontSizeMultiplier(obj)
            val = obj.getValue('axesTitleFontSizeMultiplier');
            validateattributes(val,{'numeric'},{'positive'})
        end
        
        %% validate_legendLineWidth ----------------------------------------------
        function validate_legendLineWidth(obj)
            val = obj.getValue('legendLineWidth');
            validateattributes(val,{'numeric'},{'scalar','positive'})
        end
        
        %% validate_histLineWidth ----------------------------------------------
        function validate_histLineWidth(obj)
            val = obj.getValue('histLineWidth');
            validateattributes(val,{'numeric'},{'scalar','positive'})
        end
        
        %% validate_linesLineWidth ----------------------------------------------
        function validate_linesLineWidth(obj)
            val = obj.getValue('linesLineWidth');
            validateattributes(val,{'numeric'},{'scalar','positive'})
        end
        
    end
    
    %% METHODS - PRIVATE STATIC ===========================================
    methods (Access = private, Static)
        %% fig_SizeChangedFcn ---------------------------------------------
        function fig_SizeChangedFcn(~,~)
        % Figure resize callback. Issues call to syncAxesPosition.
        % Remember that this will be called whenever a figure's Position
        % property changes (except when caused by a change in Units).
        % Though it's defined as static, it is intended to be used by 
        % property hFig only.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % get source handle
            src = gcbo; % as recommended by Mathworks
            
            % get PlotManager object
            obj = src.UserData;
            
            % set new figure dimensions to UI component values
            srcPos = src.Position;
            hWidth = obj.getUIHandle('figWidth');
            hHeight = obj.getUIHandle('figHeight');
            hWidth.String = num2str(srcPos(3));
            hHeight.String = num2str(srcPos(4));
            
            % set paper dimensions (OBSOLETE)
            %obj.updatePaperDimensions;
            
            % resync
            obj.syncAxesPosition;
        end
        
        %% fig_CloseRequestFcn --------------------------------------------
        function fig_CloseRequestFcn(~,~)
        % Figure close request callback.
        % Though it's defined as static, it is intended to be used by 
        % property hFig only.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % get source handle
            src = gcbo;
            
            % get PlotManager object
            obj = src.UserData;
            
            % call 'closeFig'
            obj.closeFig;
        end
    end
end
