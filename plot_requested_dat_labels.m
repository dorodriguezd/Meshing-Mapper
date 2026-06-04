%PLOT_REQUESTED_DAT_LABELS Plot selected labels from a custom .dat mesh.
%
% Edit labelsToPlot to use either numeric material indices or names from
% the remap log.

clear;
close all;
clc;
addpath(fullfile(pwd, 'Lib'));

datFile = fullfile(pwd, 'New_remap.dat');
logFile = fullfile(pwd, 'Output_mesh_mapped_input_label_log.txt');

% Examples:
%   labelsToPlot = [1 3];
%   labelsToPlot = ["air" "target"];
%   labelsToPlot = "all";
labelsToPlot = ["air" "cylinder" "target"];

plotDatLabels( ...
    datFile, ...
    labelsToPlot, ...
    'LogFile', logFile, ...
    'PlotMode', 'separate', ...
    'Visible', 'on', ...
    'ShowContext', true);
