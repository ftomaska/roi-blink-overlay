# Changelog

All notable changes to this project will be documented here.

## [1.0.0] — 2026-03-25 — Initial release

### Python GUI

**Data loading**
- Suite2p folder drop zone — auto-detects `ops.npy`, `stat.npy`, `iscell.npy`, `spks.npy`, `spiketimes.npy/.mat`
- Spiketimes: `.npy` object array, 2-D NaN-padded, and `.mat` v5 + v7.3 HDF5 (MATLAB cell arrays auto-dereferenced)
- `spks.npy` per-ROI normalisation before thresholding (values can be 0–5000+ AU)

**Preview**
- Live mean projection preview with W/L applied in real time
- ROI overlay toggle — paints all cell ROIs on the preview with current alpha/colour settings

**Image adjustments**
- Brightness, Contrast, Gamma (luminance), Low/High percentile clip
- Sliders + numeric entry boxes (type exact values, press Enter)

**Output**
- Output folder picker with auto-timestamped filenames
- Preview and full render saved separately with `_preview5s_` suffix

**Render**
- Background thread with progress bar and Cancel button
- Vectorised per-frame blending (`O(total_pixels)` not `O(n_rois × n_pixels)`)
- GECI difference-of-exponentials kernel, tunable τ rise / τ decay

**Style**
- Blinky animation during rendering (two-frame alternating at 2 Hz)
- macOS-compatible: `tk.Label`-based buttons (macOS overrides `tk.Button` bg)
- Dark theme, three-tier button hierarchy (primary / secondary / utility)

### MATLAB App Designer GUI
- Loads `Fall.mat` (ops, stat, iscell) + separate spiketimes `.mat`
- Deep struct search for spiketimes field (3 levels)
- Per-frame progress dialog with Cancel support
- Advanced parameters modal (clip %, global scale, quality, tail margin)
