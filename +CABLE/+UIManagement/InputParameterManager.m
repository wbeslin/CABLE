%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Class "InputParameterManager"
%   Written by Wilfried Beslin
%   Last Updated Dec 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       Parallel Computing Toolbox
%
%   Description:
%       Class for controlling all aspects of CABLE's GUI that deal with 
%       input parameters for the routine. Specific tasks include:
%           - Definition of default parameter values. These are publically 
%           accessible with no need for an instance of the class, so it is 
%           useful for non-graphical interfaces as well.
%           - Association of GUI components with specific parameters
%           - Validation of parameter values entered by the user, and the
%           display of associated warnings
%           - Retrival of parameter values from the GUI and their
%           conversion into appropriate data types that the routine can use
%           - Resetting of parameters to their default values
%       Only one instance of "InputParameterManager" must be defined to 
%       control the GUI. It is a handle class, which means the instance
%       will be SHARED when passed to an object or function, not copied. In
%       other words, if a modification is made to the instance from some
%       function somewhere, that modification will automatically apply 
%       everywhere else, even if the instance was not explicitly returned.
%
%   Constructor Input:
%       clustObj [1-by-1 parallel.Cluster]
%           Parallel cluster object defining the available parallel
%           computing cluster
%       defaultInputPath [1-by-n char]:
%           String defining path to default input file directory
%       defaultOutputPath [1-by-n char]:
%           String defining path to default output file directory
%
%   Notes:
%       - UI components must be set individually after construction
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

classdef InputParameterManager < handle
    %% PROPERTIES =========================================================
    properties (Constant)
        builtInDefaults = struct(...
        ...%%% Main
            'inputPath','',...
            'outputPath','',...
            'saveData_AllIPIs',false,...
            'saveData_FilteredIPIs',true,...
            'saveData_Clusters',true,...
            'displayPlots',true,...
            'savePlots','None',...
            'nIPIReps',1,...
            'minGoodProb',0.7,...
        ...%%% General
            'nCores',[],...
            'recSplitDuration',4,... % minutes
            'minSegmentDuration',2,... % minutes
            'channelIndex',1,...
        ...%%% Multi-Step
            'IPIRange',[2,9],... % milliseconds
            'pulseDurationRange',[0.05,1],... % milliseconds
            'tukeyFalloffDuration',5,... % milliseconds
        ...%%% Click Detection
            'threshOn',10,...
            'threshOff',1,...
            'alphaSignal',0.2,...
            'alphaNoiseOn',0.000002,...
            'alphaNoiseOff',0.0002,...
            'minEchoProp',0.6,...
            'maxClickDuration',40,... % milliseconds
            'minClickSep',0,... % seconds
        ...%%% Pulse Detection
            'smoothBandwidths',[0.5, 1, 1.5, 2],...
            'nSmoothRuns',2,...
            'peakBaseHeightProp',0.75,...
            'promThreshProp',0.05,...
            'minPromThreshScale',2,...
        ...%%% IPI Calculation and Validation
            'doIPIMethod_Autocorrelation',true,...
            'doIPIMethod_Cepstrum',true,...
            'useChiSquared_Autocorrelation',false,...
            'useChiSquared_Cepstrum',true,...
            'maxIPIDeviation',0.05,... % milliseconds
            'ICIRange',[0.25,1.5],... % seconds
            'ICITol',0.2,... % seconds
            'IPITol',0.05,... % milliseconds
        ...%%% Clustering
            'KDEBandwidths',[0.1,0.05]/3,...
            'nkExtra',1,...
            'shareSigma',true,...
            'sigma2RegVal','auto',...
            'EMTol',1e-9,...
            'maxEMIterations',1000,...
            'maxEMTries',3);
    end
    properties
        parClust    % "parallel.Cluster" object, used to determine how many CPU cores are available
    end
    properties (Constant, Hidden)
        colourValid = [1 1 1];              % Colour of GUI edit field when a parameter is valid
        colourInvalid = [255 205 205]/255;  % Colour of GUI edit field when a parameter is invalid
    end
    properties (SetAccess = private, Hidden)
        paramTable  % Massive table containing data associated with each parameter
    end
    
    
    %% METHODS - PUBLIC ===================================================
    methods
        %% Constructor ----------------------------------------------------
        function obj = InputParameterManager(clustObj,defaultInputPath,defaultOutputPath)
        % Creates an "InputParameterManager" instance with default
        % parameter values.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % set cluster object
            obj.parClust = clustObj;
            
            % create initialization cell.
            % The first column corresponds to parameter names.
            % The remaining columns correspond to the fields in the table:
            tableFields = {'Default','Dependents','UIHandle','ValidationFunction'};
            initCell = {...
                'inputPath', defaultInputPath, {}, [], @validate_inputPath;...
                'outputPath', defaultOutputPath, {}, [], @validate_outputPath;...
                'saveData_AllIPIs', obj.builtInDefaults.saveData_AllIPIs, {}, [], @validate_saveData_AllIPIs;...
                'saveData_FilteredIPIs', obj.builtInDefaults.saveData_FilteredIPIs, {}, [], @validate_saveData_FilteredIPIs;...
                'saveData_Clusters', obj.builtInDefaults.saveData_Clusters, {}, [], @validate_saveData_Clusters;...
                'displayPlots', obj.builtInDefaults.displayPlots, {}, [], @validate_displayPlots;...
                'savePlots', obj.builtInDefaults.savePlots, {}, [], @validate_savePlots;...
                'nIPIReps', obj.builtInDefaults.nIPIReps, {}, [], @validate_nIPIReps;...
                'minGoodProb', obj.builtInDefaults.minGoodProb, {}, [], @validate_minGoodProb;...
                'nCores', max(obj.parClust.NumWorkers), {}, [], @validate_nCores;...
                'recSplitDuration', obj.builtInDefaults.recSplitDuration, {'minSegmentDuration'}, [], @validate_recSplitDuration;...
                'minSegmentDuration', obj.builtInDefaults.minSegmentDuration, {'recSplitDuration'}, [], @validate_minSegmentDuration;...
                'channelIndex', obj.builtInDefaults.channelIndex, {}, [], @validate_channelIndex;...
                'IPIRange', obj.builtInDefaults.IPIRange, {'pulseDurationRange','maxClickDuration'}, [], @validate_IPIRange;...
                'pulseDurationRange', obj.builtInDefaults.pulseDurationRange, {'IPIRange','maxClickDuration'}, [], @validate_pulseDurationRange;...
                'tukeyFalloffDuration', obj.builtInDefaults.tukeyFalloffDuration, {}, [], @validate_tukeyFalloffDuration;...
                'threshOn', obj.builtInDefaults.threshOn, {}, [], @validate_threshOn;...
                'threshOff', obj.builtInDefaults.threshOff, {}, [], @validate_threshOff;...
                'alphaSignal', obj.builtInDefaults.alphaSignal, {}, [], @validate_alphaSignal;...
                'alphaNoiseOn', obj.builtInDefaults.alphaNoiseOn, {}, [], @validate_alphaNoiseOn;...
                'alphaNoiseOff', obj.builtInDefaults.alphaNoiseOff, {}, [], @validate_alphaNoiseOff;...
                'minEchoProp', obj.builtInDefaults.minEchoProp, {}, [], @validate_minEchoProp;...
                'maxClickDuration', obj.builtInDefaults.maxClickDuration, {'IPIRange','pulseDurationRange'}, [], @validate_maxClickDuration;...
                'minClickSep', obj.builtInDefaults.minClickSep, {}, [], @validate_minClickSep;...
                'smoothBandwidths', obj.builtInDefaults.smoothBandwidths, {}, [], @validate_smoothBandwidths;...
                'nSmoothRuns', obj.builtInDefaults.nSmoothRuns, {}, [], @validate_nSmoothRuns;...
                'peakBaseHeightProp', obj.builtInDefaults.peakBaseHeightProp, {}, [], @validate_peakBaseHeightProp;...
                'promThreshProp', obj.builtInDefaults.promThreshProp, {}, [], @validate_promThreshProp;...
                'minPromThreshScale', obj.builtInDefaults.minPromThreshScale, {}, [], @validate_minPromThreshScale;...
                'doIPIMethod_Autocorrelation', obj.builtInDefaults.doIPIMethod_Autocorrelation, {}, [], @validate_doIPIMethod_Autocorrelation;...
                'doIPIMethod_Cepstrum', obj.builtInDefaults.doIPIMethod_Cepstrum, {}, [], @validate_doIPIMethod_Cepstrum;...
                'useChiSquared_Autocorrelation', obj.builtInDefaults.useChiSquared_Autocorrelation, {}, [], @validate_useChiSquared_Autocorrelation;...
                'useChiSquared_Cepstrum', obj.builtInDefaults.useChiSquared_Cepstrum, {}, [], @validate_useChiSquared_Cepstrum;...
                'maxIPIDeviation', obj.builtInDefaults.maxIPIDeviation, {}, [], @validate_maxIPIDeviation;...
                'ICIRange', obj.builtInDefaults.ICIRange, {}, [], @validate_ICIRange;...
                'ICITol', obj.builtInDefaults.ICITol, {}, [], @validate_ICITol;...
                'IPITol', obj.builtInDefaults.IPITol, {}, [], @validate_IPITol;...
                'KDEBandwidths', obj.builtInDefaults.KDEBandwidths, {}, [], @validate_KDEBandwidths;...
                'nkExtra', obj.builtInDefaults.nkExtra, {}, [], @validate_nkExtra;...
                'shareSigma', obj.builtInDefaults.shareSigma, {}, [], @validate_shareSigma;...
                'sigma2RegVal', obj.builtInDefaults.sigma2RegVal, {}, [], @validate_sigma2RegVal;...
                'EMTol', obj.builtInDefaults.EMTol, {}, [], @validate_EMTol;...
                'maxEMIterations', obj.builtInDefaults.maxEMIterations, {}, [], @validate_maxEMIterations;...
                'maxEMTries', obj.builtInDefaults.maxEMTries, {}, [], @validate_maxEMTries};
            
            % create table
            obj.paramTable = cell2table(initCell(:,2:end),'RowNames',initCell(:,1),'VariableNames',tableFields);
        end
        
        %% set.parClust ---------------------------------------------------
        function set.parClust(obj,c)
            validateattributes(c,{'parallel.Cluster'},{'scalar'})
            obj.parClust = c;
        end
        
        %% setUIHandle ----------------------------------------------------
        function setUIHandle(obj,param,h)
        % Sets "UIHandle" for specified parameter.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParam = ischar(param) && ismember(param,obj.getParamList);
            if ~validParam
                error('Invalid parameter name')
            end
            
            % set h to paramTable and evaluate its type. If it's an invalid
            % type, remove it and throw an error.
            obj.paramTable.UIHandle{param} = h;
            hType = obj.getUIType(h);
            if strcmp(hType,'unknown')
                obj.paramTable.UIHandle{param} = [];
                error('Last argument is not a supported UI object')
            end
            
            % set default value
            obj.resetValue(param);
        end
        
        %% getUIHandle ----------------------------------------------------
        function h = getUIHandle(obj,params)
        % Gets "UIHandle" for specified parameters.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParams = ismember(params,obj.getParamList);
            if ~all(validParams)
                error('Invalid parameter names')
            end
            
            % get
            if iscell(params)
                h = obj.paramTable.UIHandle(params);
            else
                h = obj.paramTable.UIHandle{params};
            end
        end
        
        %% resetValue -----------------------------------------------------
        function resetValue(obj,param)
        % Sets the value of a parameter to its default. The default value
        % replaces the current string/value of the parameter's UI object.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParam = ischar(param) && ismember(param,obj.getParamList);
            if ~validParam
                error('Invalid parameter name')
            end
            
            % set default based on type
            val = obj.paramTable.Default{param};
            h = obj.getUIHandle(param);
            hType = obj.getUIType(h);
            switch hType
                case 'edit'
                    h.String = setCharData(val);
                    obj.updateUI(h,NaN)
                case 'checkbox'
                    h.Value = double(val);
                    obj.updateUI(h,NaN)
                case 'popupmenu'
                    h.Value = find(strcmp(val,h.String));
                    obj.updateUI(h,NaN);
                case 'table'
                    rowIndex = ismember(h.Data(:,1),param);
                    h.Data{rowIndex,2} = setCharData(val);
                    obj.updateUI(h,[find(rowIndex),2])
                case 'unset'
                    % do nothing
                otherwise
                    error('UI handle is not a recognized type')
            end
            
            % NESTED FUNCTIONS
            % setCharData .................................................
            function s = setCharData(v)
                if ischar(v)
                    % default is a string
                    s = v;
                elseif islogical(v)
                    % default is a logical
                    if v
                        s = 'true';
                    else
                        s = 'false';
                    end
                else
                    % default is an array of numbers
                    n = numel(v);
                    valStrCell = cell(1,n);
                    for ii = 1:n
                        valStrCell{ii} = num2str(v(ii));
                    end
                    s = strjoin(valStrCell);
                end
            end
        end
        
        %% getValue -------------------------------------------------------
        function val = getValue(obj,params)
        % Returns the value(s) of specified parameters, interpreted from
        % the UI object strings or values.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParams = ismember(params,obj.getParamList);
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
                    val{ii} = extractParamValue(paramii,hii);
                end
            else
                h = obj.getUIHandle(params);
                val = extractParamValue(params,h);
            end
            
            % NESTED FUNCTIONS 
            % extractParamValue ...........................................
            function v = extractParamValue(p,h)
                hType = obj.getUIType(h);
                switch hType
                    case 'edit'
                        % start by assuming numeric. If it turns out not to
                        % be, return the string.
                        hVal = h.String;
                        v = extractCharData(hVal);
                    case 'checkbox'
                        hVal = h.Value;
                        v = logical(hVal);
                    case 'popupmenu'
                        hVal = h.Value;
                        v = h.String{hVal};
                    case 'table'
                        rowIndex = ismember(h.Data(:,1),p);
                        hVal = h.Data{rowIndex,2};
                        v = extractCharData(hVal);
                    case 'unset'
                        error('UI handle is not yet set for this parameter')
                    otherwise
                        error('UI handle is not a recognized type')
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
                elseif strcmpi(s,'true') 
                    % logical true
                    v = true;
                elseif strcmpi(s,'false')
                    % logical false
                    v = false;
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
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % validate input
            validParams = ismember(params,obj.getParamList);
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
                try
                    feval(fii,obj);
                    validity(ii) = true;
                    errMsg{ii} = '';
                catch ME
                    validity(ii) = false;
                    errMsg{ii} = ME.message;
                end
            end
            
            if ~cellInput
                errMsg = errMsg{:};
            end
        end
        
        %% isRunnable -----------------------------------------------------
        function [canRun,errMsg] = isRunnable(obj)
        % Checks if the routine can be run based on parameter values.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % initialize variables
            
            % 1) check validity
            validParams = obj.isValid(obj.getParamList);
            if ~all(validParams)
                canRun = false;
                errMsg = 'One or more parameters is invalid';
                return
            end
            
            % 2) check output
            outValsBool = cell2mat(obj.getValue({...
                'saveData_AllIPIs';...
                'saveData_FilteredIPIs';...
                'saveData_Clusters';...
                'displayPlots'}));
            if ~any(outValsBool) && strcmp(obj.getValue('savePlots'),'None')
                canRun = false;
                errMsg = 'The routine is configured to output nothing!';
                return
            end
            
            % 3) check IPI calculation
            IPITypes = cell2mat(obj.getValue({...
                'doIPIMethod_Autocorrelation';...
                'doIPIMethod_Cepstrum'}));
            if ~any(IPITypes)
                canRun = false;
                errMsg = 'All IPI calculation methods have been deactivated!';
                return
            end
            
            % at this point, everything should be good
            canRun = true;
            errMsg = '';
        end
        
        %% updateUI -------------------------------------------------------
        function updateUI(obj,h,tableIndices)
        % Updates UI components based on the current value of the parameter
        % controlled by UI object h. This function updates the UI of the
        % current parameter and those that depend on it, based on their
        % validity. Call this function whenever a parameter value changes.
        % Makes some assumptions about UI tables: columns correspond to
        % Name, Value, and ErrorMessage. If handle is not a table, set
        % tableIndices to NaN.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % determine which parameter is controlled by h
            if isnan(tableIndices)
                nParams = numel(obj.getParamList);
                searching = true;
                m = 1;
                while searching && m <= nParams
                    hm = obj.paramTable.UIHandle{m};
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
            else
                rowIndex = tableIndices(1);
                param = h.Data{rowIndex,1};
            end
            
            % check if there are dependent parameters
            dependents = obj.paramTable.Dependents{param};
            paramsToCheck = [param,dependents];
            nChecks = numel(paramsToCheck);
            
            % check validity of each relevant parameter and update their UI 
            % objects as needed 
            for ii = 1:nChecks
                paramii = paramsToCheck{ii};
                hii = obj.getUIHandle(paramii);
                hTypeii = obj.getUIType(hii);
                [validii,emii] = obj.isValid(paramii);
                if validii
                    colourUpdate = obj.colourValid;
                else
                    colourUpdate = obj.colourInvalid;
                end
                switch hTypeii
                    case 'edit'
                        hii.BackgroundColor = colourUpdate;
                    case 'checkbox'
                        % do nothing
                    case 'popupmenu'
                        % do nothing
                    case 'table'
                        rowIndexii = ismember(hii.Data(:,1),paramii);
                        hii.BackgroundColor(rowIndexii,:) = colourUpdate;
                        hii.Data{rowIndexii,3} = emii;
                    case 'unset'
                        % can happen if some dependent parameters don't
                        % have a UI object yet. In this case, do nothing.
                    otherwise
                        error('UI handle not recognized')
                end
            end
        end
        
        %% getFormattedList -----------------------------------------------
        function fList = getFormattedList(obj)
        % Returns the name and value of every parameter as a single string
        % where parameters are seperated by \n. Use this for printing the 
        % parameter list to a text file.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            paramList = obj.getParamList;
            paramList_format = paramList(~ismember(paramList,{'inputPath';'outputPath'}));
            nParams = numel(paramList_format);
            listCellStr = cell(1,nParams);
            for ii = 1:nParams
                % get parameter info
                nameii = paramList_format{ii};
                hii = obj.getUIHandle(nameii);
                hTypeii = obj.getUIType(hii);
                switch hTypeii
                    case 'table'
                        rowIndexii = ismember(hii.Data(:,1),nameii);
                        valueStrii = hii.Data{rowIndexii,2};
                    case 'checkbox'
                        if hii.Value
                            valueStrii = 'true';
                        else
                            valueStrii = 'false';
                        end
                    case 'edit'
                        valueStrii = hii.String;
                    case 'popupmenu'
                        valueStrii = hii.String{hii.Value};
                    otherwise
                        error('UI handle type is %s. This is not supported',hTypeii)
                end
                
                % create formatted string
                listCellStr{ii} = sprintf('%s = %s\n',nameii,valueStrii);
            end
            
            % concatenate the cell array into one massive string
            fList = cell2mat(listCellStr);
        end
    end
    
    %% METHODS - PUBLIC STATIC ============================================
    methods (Static)
        %% getParamList ---------------------------------------------------
        function l = getParamList()
        % Returns the full list of parameter names.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            l = fieldnames(CABLE.UIManagement.InputParameterManager.builtInDefaults);
        end
        
        %% getUIType ------------------------------------------------------
        function typeStr = getUIType(h)
        % Returns a string indicating the type of a UI object.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            % check if h is empty, call it "unset" if so and return
            if isempty(h)
                typeStr = 'unset';
                return
            end
        
            % initialize variables
            validCtrlTypes = {'edit','checkbox','popupmenu'}; % add more as needed
            badType = 'unknown';
            hClass = class(h);
            
            % assess type
            switch hClass
                case 'matlab.ui.control.UIControl'
                    hStyle = h.Style;
                    supportedStyle = ismember(hStyle,validCtrlTypes);
                    if supportedStyle
                        typeStr = hStyle;
                    else
                        typeStr = badType;
                    end
                case 'matlab.ui.control.Table'
                    typeStr = 'table';
                otherwise
                    typeStr = badType;
            end
        end
    end
    
    %% METHODS - PRIVATE ==================================================
    methods (Access = private)
        %% validate_inputPath ---------------------------------------------
        function validate_inputPath(obj)
        % Ensures "inputPath" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('inputPath');
            assert(ischar(val) && isrow(val),'Expected input to be a string')
            assert(logical(exist(val,'file')),sprintf('Could not find file or folder:\n%s"',val))
        end
        
        %% validate_outputPath --------------------------------------------
        function validate_outputPath(obj)
        % Ensures "outputPath" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('outputPath');
            assert(ischar(val) && isrow(val),'Expected input to be a string')
            assert(logical(exist(val,'dir')),sprintf('Could not folder:\n%s"',val))
        end
        
        %% validate_saveData_AllIPIs --------------------------------------
        function validate_saveData_AllIPIs(obj)
        % Ensures "saveData_AllIPIs" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('saveData_AllIPIs');
            assert(islogical(val) && isscalar(val),'Expected input to be Boolean (true/false)')
        end
        
        %% validate_saveData_FilteredIPIs ---------------------------------
        function validate_saveData_FilteredIPIs(obj)
        % Ensures "saveData_FilteredIPIs" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('saveData_FilteredIPIs');
            assert(islogical(val) && isscalar(val),'Expected input to be Boolean (true/false)')
        end
        
        %% validate_saveData_Clusters -------------------------------------
        function validate_saveData_Clusters(obj)
        % Ensures "saveData_Clusters" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('saveData_Clusters');
            assert(islogical(val) && isscalar(val),'Expected input to be Boolean (true/false)')
        end
        
        %% validate_displayPlots ------------------------------------------
        function validate_displayPlots(obj)
        % Ensures "displayPlots" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('displayPlots');
            assert(islogical(val) && isscalar(val),'Expected input to be Boolean (true/false)')
        end
        
        %% validate_savePlots ---------------------------------------------
        function validate_savePlots(obj)
        % Ensures "savePlots" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('savePlots');
            assert(ischar(val) && isrow(val),'Expected input to be a string')
        end
        
        %% validate_nIPIReps ----------------------------------------------
        function validate_nIPIReps(obj)
        % Ensures "nIPIReps" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('nIPIReps');
            try
                validateattributes(val,{'numeric'},{'scalar','integer','nonnegative'})
            catch
                error('Expected input to be a non-negative integer')
            end
        end
        
        %% validate_minGoodProb -------------------------------------------
        function validate_minGoodProb(obj)
        % Ensures "minGoodProb" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('minGoodProb');
            assert(isnumeric(val) && isscalar(val) && val >= 0 && val <= 1,'Expected input to be a number between 0 and 1')
        end
        
        %% validate_nCores ------------------------------------------------
        function validate_nCores(obj)
        % Ensures "nCores" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('nCores');
            maxCores = obj.parClust.NumWorkers;
            try
                validateattributes(val,{'numeric'},{'scalar','integer','positive'})
            catch
                error('Expected input to be an integer > 0')
            end
            assert(val <= maxCores,sprintf('Maximum number of cores available is %d',maxCores))
        end
        
        %% validate_recSplitDuration --------------------------------------
        function validate_recSplitDuration(obj)
        % Ensures "recSplitDuration" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('recSplitDuration');
            % Check dependents
            try
                minSegmentDuration = obj.getValue('minSegmentDuration');
            catch
                error('One or more dependent parameters is unset or invalid')
            end
            % Check input type
            assert(isnumeric(val) && isscalar(val) && val >= 0,'Expected input to be a non-negative number')
            % Check conditions
            assert(val >= minSegmentDuration,'recSplitDuration must be >= minSegmentDuration')
        end
        
        %% validate_minSegmentDuration ------------------------------------
        function validate_minSegmentDuration(obj)
        % Ensures "minSegmentDuration" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('minSegmentDuration');
            % Check dependents
            try
                recSplitDuration = obj.getValue('recSplitDuration');
            catch
                error('One or more dependent parameters is unset or invalid')
            end
            % Check input type
            assert(isnumeric(val) && isscalar(val) && val >= 0,'Expected input to be a non-negative number')
            % Check condition
            assert(val <= recSplitDuration,'minSegmentDuration must be <= recSplitDuration')
        end
        
        %% validate_channelIndex ------------------------------------------
        function validate_channelIndex(obj)
        % Ensures "channelIndex" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('channelIndex');
            try
                validateattributes(val,{'numeric'},{'scalar','integer','positive'})
            catch
                error('Expected input to be an integer > 0')
            end
        end
        
        %% validate_IPIRange ----------------------------------------------
        function validate_IPIRange(obj)
        % Ensures "IPIRange" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('IPIRange');
            try
                validateattributes(val,{'numeric'},{'numel',2,'nonnegative','increasing'})
            catch
                error('Expected input to contain 2 non-negative numbers increasing in magnitude')
            end
        end
        
        %% validate_pulseDurationRange ------------------------------------
        function validate_pulseDurationRange(obj)
        % Ensures "pulseDurationRange" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('pulseDurationRange');
            % Check dependents
            try
                maxClickDuration = obj.getValue('maxClickDuration');
                IPIRange = obj.getValue('IPIRange');
                minIPI = IPIRange(1);
            catch
                error('One or more dependent parameters is unset or invalid')
            end
            % Check input type
            try
                validateattributes(val,{'numeric'},{'numel',2,'nonnegative','increasing'})
            catch
                error('Expected input to contain 2 non-negative numbers increasing in magnitude')
            end
            % Check conditions
            assert(val(2) <= (maxClickDuration-minIPI-val(1)),'Upper pulse duration is too long for current maxClickDuration and IPIRange')
        end
        
        %% validate_tukeyFalloffDuration ----------------------------------
        function validate_tukeyFalloffDuration(obj)
        % Ensures "tukeyFalloffDuration" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('tukeyFalloffDuration');
            assert(isnumeric(val) && isscalar(val) && val >= 0,'Expected input to be a non-negative number')
        end
        
        %% validate_threshOn ----------------------------------------------
        function validate_threshOn(obj)
        % Ensures "threshOn" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('threshOn');
            assert(isnumeric(val) && isscalar(val),'Expected input to be a number')
        end
        
        %% validate_threshOff ---------------------------------------------
        function validate_threshOff(obj)
        % Ensures "threshOff" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('threshOff');
            assert(isnumeric(val) && isscalar(val),'Expected input to be a number')
        end
        
        %% validate_alphaSignal -------------------------------------------
        function validate_alphaSignal(obj)
        % Ensures "alphaSignal" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('alphaSignal');
            assert(isnumeric(val) && isscalar(val) && val >= 0,'Expected input to be a non-negative number')
        end
        
        %% validate_alphaNoiseOn ------------------------------------------
        function validate_alphaNoiseOn(obj)
        % Ensures "alphaNoiseOn" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('alphaNoiseOn');
            assert(isnumeric(val) && isscalar(val) && val >= 0,'Expected input to be a non-negative number')
        end
        
        %% validate_alphaNoiseOff -----------------------------------------
        function validate_alphaNoiseOff(obj)
        % Ensures "alphaNoiseOff" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('alphaNoiseOff');
            assert(isnumeric(val) && isscalar(val) && val >= 0,'Expected input to be a non-negative number')
        end
        
        %% validate_minEchoProp -------------------------------------------
        function validate_minEchoProp(obj)
        % Ensures "minEchoProp" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('minEchoProp');
            assert(isnumeric(val) && isscalar(val) && val >= 0,'Expected input to be a non-negative number')
        end
        
        %% validate_maxClickDuration --------------------------------------
        function validate_maxClickDuration(obj)
        % Ensures "maxClickDuration" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('maxClickDuration');
            % Check dependents
            try
                IPIRange = obj.getValue('IPIRange');
                maxIPI = IPIRange(2);
                pulseDurationRange = obj.getValue('pulseDurationRange');
                minPulseDuration = pulseDurationRange(1);
            catch
                error('One or more dependent parameters is unset or invalid')
            end
            % Check input type
            assert(isnumeric(val) && isscalar(val) && val >= 0,'Expected input to be a non-negative number')
            % Check conditions
            assert(val >= (maxIPI + 2*minPulseDuration),'maxClickDuration is too short for current IPIRange and pulseDurationRange')
        end
        
        %% validate_minClickSep -------------------------------------------
        function validate_minClickSep(obj)
        % Ensures "minClickSep" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('minClickSep');
            assert(isnumeric(val) && isscalar(val) && val >= 0,'Expected input to be a non-negative number')
        end
        
        %% validate_smoothBandwidths --------------------------------------
        function validate_smoothBandwidths(obj)
        % Ensures "smoothBandwidths" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('smoothBandwidths');
            try
                validateattributes(val,{'numeric'},{'vector','nonnegative','increasing'})
            catch
                error('Expected input to be a vector of non-negative numbers increasing in magnitude')
            end
        end
        
        %% validate_nSmoothRuns -------------------------------------------
        function validate_nSmoothRuns(obj)
        % Ensures "nSmoothRuns" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('nSmoothRuns');
            try
                validateattributes(val,{'numeric'},{'scalar','integer','positive'})
            catch
                error('Expected input to be an integer > 0')
            end
        end
        
        %% validate_peakBaseHeightProp ------------------------------------
        function validate_peakBaseHeightProp(obj)
        % Ensures "peakBaseHeightProp" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('peakBaseHeightProp');
            assert(isnumeric(val) && isscalar(val) && val > 0 && val <= 1,'Expected input to be a number > 0 and <= 1')
        end
        
        %% validate_promThreshProp ----------------------------------------
        function validate_promThreshProp(obj)
        % Ensures "promThreshProp" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('promThreshProp');
            assert(isnumeric(val) && isscalar(val) && val >= 0, 'Expected input to be a non-negative number')
        end
        
        %% validate_minPromThreshScale ------------------------------------
        function validate_minPromThreshScale(obj)
        % Ensures "minPromThreshScale" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('minPromThreshScale');
            assert(isnumeric(val) && isscalar(val) && val >= 0, 'Expected input to be a non-negative number')
        end
        
        %% validate_doIPIMethod_Autocorrelation ------------------------------
        function validate_doIPIMethod_Autocorrelation(obj)
        % Ensures "doIPIMethod_Autocorrelation" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('doIPIMethod_Autocorrelation');
            assert(islogical(val) && isscalar(val),'Expected input to be Boolean (true/false)')
        end
        
        %% validate_doIPIMethod_Cepstrum -------------------------------------
        function validate_doIPIMethod_Cepstrum(obj)
        % Ensures "doIPIMethod_Cepstrum" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('doIPIMethod_Cepstrum');
            assert(islogical(val) && isscalar(val),'Expected input to be Boolean (true/false)')
        end
        
        %% validate_useChiSquared_Autocorrelation -------------------------
        function validate_useChiSquared_Autocorrelation(obj)
        % Ensures "useChiSquared_Autocorrelation" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('useChiSquared_Autocorrelation');
            assert(islogical(val) && isscalar(val),'Expected input to be Boolean (true/false)')
        end
        
        %% validate_useChiSquared_Cepstrum --------------------------------
        function validate_useChiSquared_Cepstrum(obj)
        % Ensures "useChiSquared_Cepstrum" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('useChiSquared_Cepstrum');
            assert(islogical(val) && isscalar(val),'Expected input to be Boolean (true/false)')
        end
        
        %% validate_maxIPIDeviation ---------------------------------------
        function validate_maxIPIDeviation(obj)
        % Ensures "maxIPIDeviation" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('maxIPIDeviation');
            assert(isnumeric(val) && isscalar(val) && val >= 0, 'Expected input to be a non-negative number')
        end
        
        %% validate_ICIRange ----------------------------------------------
        function validate_ICIRange(obj)
        % Ensures "ICIRange" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('ICIRange');
            try
                validateattributes(val,{'numeric'},{'numel',2,'nonnegative','nondecreasing'})
            catch
                error('Expected input to contain 2 non-negative numbers increasing in magnitude')
            end
        end
        
        %% validate_ICITol ------------------------------------------------
        function validate_ICITol(obj)
        % Ensures "ICITol" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('ICITol');
            assert(isnumeric(val) && isscalar(val) && val >= 0, 'Expected input to be a non-negative number')
        end
        
        %% validate_IPITol ------------------------------------------------
        function validate_IPITol(obj)
        % Ensures "IPITol" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('IPITol');
            assert(isnumeric(val) && isscalar(val) && val >= 0, 'Expected input to be a non-negative number')
        end
        
        %% validate_KDEBandwidths -----------------------------------------
        function validate_KDEBandwidths(obj)
        % Ensures "KDEBandwidths" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('KDEBandwidths');
            try
                validateattributes(val,{'numeric'},{'numel',2,'positive','nonincreasing'})
            catch
                error('Expected input to contain 2 numbers > 0 decreasing in magnitude')
            end
        end
        
        %% validate_nkExtra -----------------------------------------------
        function validate_nkExtra(obj)
        % Ensures "nkExtra" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('nkExtra');
            try
                validateattributes(val,{'numeric'},{'scalar','nonnegative','integer'})
            catch
                error('Expected input to be a non-negative integer')
            end
        end
        
        %% validate_shareSigma --------------------------------------------
        function validate_shareSigma(obj)
        % Ensures "shareSigma" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('shareSigma');
            assert(islogical(val) && isscalar(val),'Expected input to be Boolean (true/false)')
        end
        
        %% validate_sigma2RegVal ------------------------------------------
        function validate_sigma2RegVal(obj)
        % Ensures "sigma2RegVal" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('sigma2RegVal');
            errmsg = 'Expected input to be a nonnegative number or the string ''auto''';
            if ischar(val)
                assert(strcmp(val,'auto'),errmsg)
            else
                assert(val >= 0,errmsg)
            end
        end
        
        %% validate_EMTol ------------------------------------------------
        function validate_EMTol(obj)
        % Ensures "EMTol" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('EMTol');
            assert(isnumeric(val) && isscalar(val) && val > 0, 'Expected input to be a number > 0')
        end
        
        %% validate_maxEMIterations ---------------------------------------
        function validate_maxEMIterations(obj)
        % Ensures "maxEMIterations" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('maxEMIterations');
            try
                validateattributes(val,{'numeric'},{'scalar','positive','integer'})
            catch
                error('Expected input to be an integer > 0')
            end
        end
        
        %% validate_maxEMTries --------------------------------------------
        function validate_maxEMTries(obj)
        % Ensures "maxEMTries" is valid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            val = obj.getValue('maxEMTries');
            try
                validateattributes(val,{'numeric'},{'scalar','positive','integer'})
            catch
                error('Expected input to be an integer > 0')
            end
        end
    end
end