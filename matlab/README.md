# ROI Blink Overlay — MATLAB

MATLAB App Designer GUI for rendering Suite2p ROIs as blinking fluorescence overlays.

## Requirements

- MATLAB R2019b or newer
- Image Processing Toolbox
- `overlayBlinkingROIs_onMean.m` on your MATLAB path

## Run

```matlab
addpath('/path/to/roi-blink-overlay/matlab')
ROIBlinkOverlayApp
% or
launch_ROI_overlay_GUI
```

## File inputs

| File | Contents |
|---|---|
| `Fall.mat` | `ops` (with `meanImg`, `fs`), `iscell`, `stat` |
| Spiketimes `.mat` | `path1_phys.spiketimes` or any nested struct field |

## Notes

- FPS is read automatically from `ops.fs`
- Spiketimes file is loaded separately from `Fall.mat`
- The app calls `overlayBlinkingROIs_onMean.m` under the hood — make sure it is on your path
- For a progress bar during rendering, use the Generate MP4 button (calls `callCoreWithProgress` internally)
