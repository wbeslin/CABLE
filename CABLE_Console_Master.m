% Interface for function to run CABLE from the command line (no GUI).
% Change I/O paths and options as needed.
% Aug 2018
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% input files
%inputFiles = {'D:\Academics\MSc-Dal\Thesis\Data Analysis\MATLAB\Final Code\Examples\DOM_20150320.wav'};
%inputFiles = {'D:\Academics\MSc-Dal\Thesis\Data Analysis\MATLAB\manual IPI calculation\completed\input\Average1_182.mat'};
inputFiles = {'D:\Academics\MSc-Dal\Thesis\Data\DOM2015\4 min\D15_20150330_180124.wav'};

% output files
outputFiles = {};

% parameters
nIPIReps = 1;
minGoodProb = 0.7;
doDebug = true;
doAllIPIs = true;
doFilteredIPIs = false;
doClusters = false;

% run routine
IPIData = CABLE_console(inputFiles,outputFiles,...
    nIPIReps,minGoodProb,doDebug,doAllIPIs,doFilteredIPIs,doClusters);