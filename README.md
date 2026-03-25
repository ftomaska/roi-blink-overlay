# ROI Blink Overlay

> Visualise calcium imaging neural activity as blinking ROI overlays on a Suite2p mean projection.

Convolves each neuron's spike train with a GECI calcium kernel and renders an MP4 where each ROI lights up proportional to its inferred fluorescence — overlaid on the mean projection image. Available as a **Python GUI** and a **MATLAB App Designer** app.

---


## Features

- **One-click folder loading** — point to a Suite2p output folder, all files detected automatically
- **Flexible spiketimes input** — `.npy` (object array, 2-D NaN-padded) and `.mat` v5/v7.3 HDF5
- **`spks.npy` support** — deconvolved trace, normalised per-ROI before thresholding
- **ROI overlay preview** — see ROIs painted on the mean image before rendering, with live alpha/colour updates
- **Full W/L control** — Brightness, Contrast, Gamma, Low/High percentile clip with slider + numeric entry
- **Output folder** — auto-timestamped filenames; previews and full renders saved separately
- **GECI kernel** — tunable τ rise / τ decay for any indicator (GCaMP6f, GCaMP6s, jGCaMP8, etc.)
- **Colour modes** — single colour or unique HSV per ROI
- **macOS / Windows / Linux**

## GUI

<img width="1512" height="982" alt="screenshot" src="https://github.com/user-attachments/assets/e2590bf5-5fd7-47f2-b9c6-6e0d68aefb50" />



---

## Quick start

### Python

```bash
git clone https://github.com/YOUR_USERNAME/roi-blink-overlay
cd roi-blink-overlay/python
bash setup_env.sh          # creates conda env 'roi_blink' or a venv
conda activate roi_blink   # or: source roi_blink/bin/activate
python roi_blink_overlay.py
```

> **`.mat` v7.3 files** also require `pip install h5py`

### MATLAB

```matlab
addpath('matlab')
ROIBlinkOverlayApp
```

Requires MATLAB R2019b+, Image Processing Toolbox.

---

## Workflow

| Step | Action |
|---|---|
| 1 | Click **Browse folder** → select Suite2p output directory |
| 2 | App auto-detects `ops.npy`, `stat.npy`, `iscell.npy` |
| 3 | Browse spiketimes (`.npy` or `.mat`) — or click **Use spks.npy** |
| 4 | Toggle **Show ROIs on preview** to check coverage and alpha visually |
| 5 | Adjust W/L, Gamma, colour and alpha to taste |
| 6 | Set output folder (📁 button) |
| 7 | **▶ Preview** to render a short test clip |
| 8 | **⬛ Generate MP4** for the full recording |

---

## Spiketimes formats

| Format | Notes |
|---|---|
| `.npy` object array | `np.array([arr0, arr1, ...], dtype=object)`, times in seconds |
| `.npy` 2-D NaN-padded | `[n_units × max_spikes]` float array |
| `.mat` v5/v6/v7 | Any struct with `spiketimes`/`spks` field, searched 3 levels deep |
| `.mat` v7.3 HDF5 | MATLAB cell arrays auto-dereferenced via `h5py` |
| `spks.npy` | Suite2p deconvolved trace `[N_rois × T_frames]`, normalised per-ROI |

---

## Parameters

### Calcium kernel

```
kernel(t) = exp(-t / τ_decay) - exp(-t / τ_rise),  normalised to peak = 1
```

| | Default | GCaMP6f | GCaMP6s |
|---|---|---|---|
| τ rise (s) | 0.07 | 0.05–0.08 | 0.15–0.20 |
| τ decay (s) | 0.70 | 0.4–0.6 | 1.2–1.8 |

### Image adjustments

Applied in order: **percentile stretch → gamma → contrast → brightness → clip [0,1]**

| Control | Range |
|---|---|
| Brightness | −100 – +100 |
| Contrast | 0.1 – 4× |
| Gamma | 0.2 – 4.0 |
| Low pct clip | 0 – 20% |
| High pct clip | 80 – 100% |

---

## Requirements

### Python

```
numpy >= 1.21
scipy >= 1.7
Pillow >= 9.0
imageio[ffmpeg] >= 2.28
imageio-ffmpeg >= 0.4.7
scikit-image >= 0.19
h5py >= 3.0        # optional — needed for .mat v7.3 only
tkinter            # stdlib (python3-tk on Linux, python-tk via brew on Mac)
```

### MATLAB
- R2019b or newer, Image Processing Toolbox

---

## Repository structure

```
roi-blink-overlay/
├── python/
│   ├── roi_blink_overlay.py     # Self-contained GUI + render engine
│   ├── requirements.txt
│   └── setup_env.sh
├── matlab/
│   ├── ROIBlinkOverlayApp.m
│   └── launch_ROI_overlay_GUI.m
├── docs/
│   ├── parameters.md
│   └── development.md
├── assets/
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

---

## License

MIT — see [LICENSE](LICENSE). © 2026 Filip Tomaska.
