%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function "importLengthEquations"
%   Written by Wilfried Beslin
%   Last Updated May 2018, using MATLAB version R2015a
%   Toolbox Dependencies:
%       none
%
%   Description:
%       Reads polynomial coefficients listed in text files in a directory,
%       and returns them in a MATLAB table. Use this to create the
%       equations for converting sperm whale IPIs to body lengths.
%
%   Input:
%       eqDir [1-by-n char]:
%           Path string pointing to the directory containing the polynomial
%           files
%
%   Output:
%       eqTable [n-by-2 table]:
%           Table containing the names and coefficients of each polynomial
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function eqTable = importLengthEquations(eqDir)

    % read every text file
    searchStr = [eqDir,filesep,'*.txt'];
    files = dir(searchStr);
    nFiles = numel(files);
    
    % initialize containers
    eqNames = cell(nFiles,1);
    eqCoeffs = cell(nFiles,1);
    
    % loop through each file and read coefficients
    m = 1;
    while m <= nFiles
        filename_m = files(m).name;
        filepath_m = fullfile(eqDir,filename_m);
        try
            coeffs_m = dlmread(filepath_m);
            validateattributes(coeffs_m,{'numeric'},{'vector'})
            [~,name_m] = fileparts(filename_m);
            eqNames{m} = name_m;
            eqCoeffs{m} = coeffs_m;
            m = m + 1;
        catch ME
            warning('Failed to import file ''%s''.\n%s',filename_m,ME.message)
            eqNames(m) = [];
            eqCoeffs(m) = [];
            nFiles = nFiles - 1;
        end
    end
    
    % create table
    eqTable = table(eqNames,eqCoeffs,'VariableNames',{'Name','Coefficients'});
    
end