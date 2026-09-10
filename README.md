# CABLE (Cachalot Automatic Body Length Estimator)
Program for the automatic acoustic estimation of sperm whale size distributions.

Written by Wilfried Beslin

## Overview
CABLE is a program that can estimate the size distributions of sperm whales from acoustic recordings, based on the inter-pulse intervals (IPIs) within the sperm whales' clicks. The program was developed as part of the following publication:

Beslin, W. A. M., Whitehead, H., and Gero, S. (**2018**). “Automatic acoustic estimation of sperm whale size distributions achieved through machine recognition of on-axis clicks”. *The Journal of the Acoustical Society of America* **144**, 3485-3495. doi: 10.1121/1.5082291

This repository contains the source code for the program documented at: http://whitelab.biology.dal.ca/CABLE/cable.htm

It was developed using MATLAB version R2015a with several additional toolboxes, including the Signal Processing Toolbox, Statistics and Machine Learning Toolbox, Curve Fitting Toolbox, and Parallel Processing Toolbox. The code may not run properly without these toolboxes. The code may also need to be edited to work with more recent versions of MATLAB.

## Usage
There are two ways to use CABLE from source: 1) via a GUI, or 2) via the MATLAB command line. To use the GUI version, simply run the file "+CABLE/CABLE_GUI.m". To use CABLE without a GUI, run "+CABLE_Console.m". Note that CABLE_Console.m is implemented as a MATLAB function and requires several input arguments. If you prefer not to pass input arguments manually from the MATLAB Command Window, the file "CABLE_Console_Master.m" is provided as a wrapper script for "CABLE_Console.m" that you can use to specify input arguments directly.
