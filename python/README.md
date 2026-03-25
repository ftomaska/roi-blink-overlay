# ROI Blink Overlay — Python

Python GUI for rendering Suite2p ROIs as blinking fluorescence overlays.

## Install

```bash
bash setup_env.sh        # creates 'roi_blink' conda env or venv
conda activate roi_blink # or: source roi_blink/bin/activate
```

**Extra dependency for `.mat` v7.3 files:**
```bash
pip install h5py
```

**Drag-and-drop support (optional):**
```bash
pip install tkinterdnd2
```

**Mac — if tkinter is missing:**
```bash
brew install python-tk
```

**Linux:**
```bash
sudo apt install python3-tk
```

## Run

```bash
python roi_blink_overlay.py
```

## File inputs

| File | Source | Notes |
|---|---|---|
| `ops.npy` | Suite2p | Contains `meanImg` and `fs` |
| `stat.npy` | Suite2p | ROI pixel coordinates |
| `iscell.npy` | Suite2p | Cell classification |
| `spiketimes.npy/.mat` | Your pipeline | See formats below |
| `spks.npy` | Suite2p | Deconvolved trace; normalised + thresholded |

Drop the entire Suite2p output folder onto the drop zone — the app finds all files automatically.

## Spiketimes formats

```python
# Object array (recommended)
np.save('spiketimes.npy', np.array([spk_unit_0, spk_unit_1, ...], dtype=object))

# 2-D NaN-padded matrix
np.save('spiketimes.npy', spike_matrix)   # [n_units × max_spikes]

# .mat file (v5 or v7.3) — any struct field named spiketimes/spks/etc.
# Searched up to 3 levels deep automatically
```

All times in **seconds**.
