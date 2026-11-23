% Run the player and CPU game with paths resolved from this file.
clc
clear

launcherFolder = fileparts(mfilename('fullpath'));
addpath(launcherFolder, fileparts(launcherFolder));

cameraInput = webcam('USB Camera') % Replace with webcam(3) when camera detection is implemented.
runMainControl(cameraInput);
