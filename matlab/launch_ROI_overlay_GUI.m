%% launch_ROI_overlay_GUI.m
%
% One-line launcher for the ROI Blink Overlay App.
%
% Prerequisites
%   • MATLAB R2019b or newer  (App Designer uifigure runtime)
%   • Image Processing Toolbox  (im2double, prctile, imresize)
%   • VideoWriter  (built-in MATLAB)
%
% Files needed on your MATLAB path (same folder is fine):
%   ROIBlinkOverlayApp.m          — this GUI class
%   overlayBlinkingROIs_onMean.m  — your original rendering function
%
% Usage:
%   Just run this file, or type ROIBlinkOverlayApp in the Command Window.
%
% Workflow:
%   1. Click "Load Fall.mat"
%        → reads ops.fs (FPS), ops.meanImg, iscell, stat
%   2. Click "Load spiketimes .mat"
%        → reads path1_phys.spiketimes (also accepts top-level spks / spiketimes)
%   3. (Optional) Click "Load image / mat override"
%        → replace the mean projection with a jpg / tif / png /
%          or a second .mat containing ops.meanImg
%   3. Use the Brightness / Contrast / Percentile-clip sliders,
%      then click "Apply W/L" to update the preview.
%   4. Fill in τ rise, τ decay, Duration, Speed, Output filename.
%      Leave Duration / N Frames blank for auto (last spike + margin).
%   5. Hit "▶ Preview 5 s" to generate a short test clip first.
%   6. Click "⬛ Generate MP4" for the full render.
%   7. "⚙ Advanced" exposes ClipPercent, GlobalScale, encoder quality,
%      VideoWriter profile, and tail-margin multiplier.
%
% The app calls overlayBlinkingROIs_onMean() with all parameters
% collected from the UI, so the rendering logic is unchanged.

app = ROIBlinkOverlayApp();
