%% patch registration setup
% run this file to prepare the patch registration toolbox.

%% required toolboxes
% the following toolboxes are required for patchRegistration

% mgh toolbox. available at https://github.com/adalca/mgt
PATHS.mgt = '/path/to/mgt';

% mmit toolbox. available at https://github.com/adalca/mmit
PATHS.mmit = '/path/to/mmit';

% mmit toolbox. available at https://github.com/adalca/patchlib
PATHS.patchlib = '/path/to/patchlib';

% ugm path. available at http://www.cs.ubc.ca/~schmidtm/Software/UGM.html.
PATHS.ugm = '/path/to/UGM';

% patch registration
PATHS.patchRegistration = fileparts(mfilename('fullpath'));

%% add paths
allpaths = struct2cell(PATHS);
addpath(genpath(allpaths));

%% settings
% turn off backtrace for warnings.
warning off backtrace; 
