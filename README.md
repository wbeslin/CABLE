# CABLE (Cachalot Automatic Body Length Estimator)
*Program for the automatic acoustic estimation of sperm whale size distributions.*

Written by Wilfried Beslin

Last updated 2026-09-12

## Introduction
CABLE is a program that can estimate the size distributions of sperm whales from acoustic recordings, based on the inter-pulse intervals (IPIs) within the sperm whales' clicks. The program was developed as part of the following publication:

>Beslin, W. A. M., Whitehead, H., and Gero, S. (**2018**). “Automatic acoustic estimation of sperm whale size distributions achieved through machine recognition of on-axis clicks”. *The Journal of the Acoustical Society of America* **144**, 3485-3495. doi: [10.1121/1.5082291](https://doi.org/10.1121/1.5082291)

CABLE was originally distributed as a pre-compiled MATLAB application here: <http://whitelab.biology.dal.ca/CABLE/cable.htm>. This GitHub repository contains the source code for CABLE. For more information about how CABLE works, follow the link above or consult the aforementioned publication. The user manual for the compiled version of CABLE is also included in this repository.

CABLE was developed using MATLAB version R2015a with several additional toolboxes, including the Signal Processing Toolbox, Statistics and Machine Learning Toolbox, Curve Fitting Toolbox, and Parallel Processing Toolbox. ***The source version of CABLE will not work without these toolboxes, and it is not guaranteed to run properly on more modern versions of MATLAB***.

## Usage
There are two ways to use CABLE from source: 1) via a GUI, or 2) via the MATLAB command line. 

### Running the CABLE GUI
To use the GUI version of CABLE, simply run the file `+CABLE/CABLE_GUI.m`. This should work exactly like the compiled version.

### Running CABLE from the command line
The CABLE routine can be run without launching a GUI. This is possible by running the custom MATLAB function `CABLE_Console`, which is defined within the file `+CABLE/CABLE_Console.m`. Note that you must specify input arguments directly in the Command Window when using this function. Alternatively, input arguments may be specified via the file `CABLE_Console_Master.m` located in CABLE's root directory. This file is simply a wrapper script for `CABLE_Console` where input parameters can be defined programmatically and passed to the function. For an explanation of the parameters, review the code file headers or consult the user manual.
