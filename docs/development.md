# Development Notes

## Architecture

### Python (`roi_blink_overlay.py`)

Single-file app (~1700 lines) split into two logical sections:

**Rendering engine** (top ~350 lines, no GUI deps)
- `build_kernel()` — GECI difference-of-exponentials kernel
- `load_spiketimes()` — dispatcher for `.npy` and `.mat` formats
- `_load_spiketimes_npy()` — handles object arrays, 2-D NaN-padded, dicts
- `_load_spiketimes_mat()` — scipy (v5/v7) + h5py (v7.3 HDF5) with deep struct search
- `_h5_deref()` — dereferences MATLAB cell arrays stored as HDF5 object references
- `compute_traces()` — spike convolution via `scipy.fftconvolve`
- `render_video()` — vectorised frame loop with `imageio` output

**GUI** (`App` class, tkinter)
- `_build_sidebar()` — scrollable left panel with all controls
- `_build_preview()` — right panel: canvas + progress bar + log
- `_load_suite2p_folder()` — folder scan, finds ops/stat/iscell/spks automatically
- `_binarize_spks()` — per-ROI normalisation + thresholding of `spks.npy`
- `_apply_wl_silent()` — real-time W/L + gamma applied on slider move (debounced 80ms)
- `_start_render()` — launches worker thread, starts blinky animation
- `_poll_queue()` — 80ms polling loop bridges worker thread → main thread

### MATLAB (`ROIBlinkOverlayApp.m`)

App Designer `classdef` with two sections:

**UI** — all `build*` methods construct the sidebar using `uigridlayout` rows.
Each section (Fall, Spikes, W/L, Kernel, Render, Style) occupies its own set of
`LeftScroll` rows directly — no nested multi-row sub-grids (these caused invisible
widgets in early versions).

**Rendering** — `callCoreWithProgress()` re-implements the frame loop from
`overlayBlinkingROIs_onMean.m` inline so it can update a `uiprogressdlg` per-frame
and support Cancel. The original function is still called via `callCore()` for
programmatic use.

---

## Key design decisions

### Vectorised blending (both versions)

Instead of looping `for roi in rois: for channel in [R,G,B]: frame[roi_pixels] = blend(...)`,
all ROI pixel indices are pre-concatenated into a flat index array before the loop.
Each frame then does:

```python
px_alpha = alphas[roi_of]          # [total_pixels]
px_color = cmap[roi_of, :]         # [total_pixels × 3]
frame_flat[active_idx] = (1 - aa) * frame_flat[active_idx] + aa * ac
```

This reduces per-frame work from `O(n_rois × n_channels × n_pixels_per_roi)`
to `O(total_pixels)` with numpy broadcasting.

### Spike normalisation for `spks.npy`

Suite2p's `spks.npy` is a deconvolved probability trace in arbitrary units
(typically 0–5000+). Before thresholding, each ROI's trace is divided by its
own maximum so the threshold parameter is always a fraction of peak activity,
making it scale-invariant across ROIs and recording conditions.

### `.mat` v7.3 cell array loading

MATLAB cell arrays of spike-time vectors are stored in HDF5 as arrays of
`h5py.Reference` objects pointing into a `#refs#` pool group. The loader:
1. Detects `h5py.Reference` dtype in the dataset
2. Iterates `.flat` to get individual refs
3. Dereferences each via `h5file[ref][()]`
4. Returns a Python list of 1-D arrays

### W/L pipeline order

```
raw_image
  → percentile stretch (lo/hi clip)
  → gamma curve  (im = im ** gamma)
  → contrast     (im = im * contrast)
  → brightness   (im = im + brightness/100)
  → clip [0, 1]
```

Gamma is applied before linear transforms so it acts on the normalised [0,1]
range, matching standard photographic gamma correction.

---

## Known limitations

- MATLAB version requires `overlayBlinkingROIs_onMean.m` on the path
- Python `imageio` encoder requires `ffmpeg` — installed via `imageio-ffmpeg`
- `tkinterdnd2` is optional; without it, drag-and-drop is replaced by Browse button
- Very large recordings (>30 min, >500 ROIs) may be slow — consider reducing
  duration or using the Preview feature to check settings first

---

## Extending

### Adding a new file format for spiketimes

In `roi_blink_overlay.py`, add a branch in `load_spiketimes()`:

```python
def load_spiketimes(path: str) -> list:
    ext = Path(path).suffix.lower()
    if ext == '.mat':
        return _load_spiketimes_mat(path)
    elif ext == '.h5':
        return _load_spiketimes_hdf5(path)   # your new function
    else:
        return _load_spiketimes_npy(path)
```

### Adding a new overlay color mode

In `render_video()`, the `cmap` array is `[n_rois × 3]` float32. Any mapping
from ROI index → RGB is valid:

```python
if color_by_roi == 'depth':
    # colour by cortical depth stored in stat
    depths = np.array([stat[i].get('depth', 0) for i in roi_is_cell])
    depths = (depths - depths.min()) / max(depths.ptp(), 1)
    cmap   = plt.cm.viridis(depths)[:, :3].astype(np.float32)
```
