# Parameter Reference

Full reference for all parameters in the ROI Blink Overlay GUI.

---

## Calcium kernel

The kernel models the fluorescence response of a GECI (e.g. GCaMP) to a spike.
It is a difference-of-exponentials:

```
kernel(t) = exp(-t / τ_decay) - exp(-t / τ_rise)
```

normalised so its peak equals 1.

| Parameter | Field | Typical range | Notes |
|---|---|---|---|
| τ rise (s) | `tau_rise` | 0.05 – 0.15 | GCaMP6f ≈ 0.05 s, GCaMP6s ≈ 0.18 s |
| τ decay (s) | `tau_decay` | 0.3 – 2.0 | GCaMP6f ≈ 0.5 s, GCaMP6s ≈ 1.5 s |

---

## Render parameters

| Parameter | Default | Notes |
|---|---|---|
| Duration (s) | 0 (auto) | 0 = compute from last spike + tail margin. Override to clip or extend. |
| N frames | 0 (auto) | Overrides Duration if set. |
| Playback speed | 2× | 2× means the video plays back at twice the acquisition rate. |
| Output filename | `roi_blink_overlay.mp4` | Extension `.mp4` is appended automatically if omitted. |

### Auto duration

When Duration = 0 and N frames = 0, the video ends at:

```
T_end = t_last_spike + (Extra seconds after last spike) × max(τ_decay, τ_rise)
```

The "Extra seconds after last spike" is set in the Advanced panel (default 5).

---

## Overlay style

| Parameter | Default | Notes |
|---|---|---|
| Color mode | Single color | "Unique per ROI" assigns a distinct HSV color to each ROI. |
| R / G / B | 1 / 1 / 1 (white) | Only used in Single color mode. |
| Alpha max | 0.85 | Opacity at peak ΔF/F. 1.0 = fully opaque at peak. |

---

## W/L controls

Applied to the mean projection before it is written into each frame.
These controls do **not** affect the ROI overlay, only the background image.

| Control | Range | Effect |
|---|---|---|
| Brightness | -100 – +100 | Additive offset to pixel values (scaled 0–1) |
| Contrast × | 0.1 – 4× | Multiplicative contrast stretch |
| Low pct clip | 0 – 20% | Pixels below this percentile are mapped to black |
| High pct clip | 80 – 100% | Pixels above this percentile are mapped to white |

Click **Apply W/L** to update the preview. Click **Reset** to restore defaults.

---

## Advanced parameters

### Base image contrast

These are applied during rendering (separate from the W/L sliders, which are
applied interactively). They define the percentile stretch for `baseIm`:

```matlab
lo = prctile(meanIm(:), BaseContrast(1));
hi = prctile(meanIm(:), BaseContrast(2));
baseIm = (meanIm - lo) / (hi - lo);
```

### Trace normalisation

| Parameter | Default | Notes |
|---|---|---|
| ClipPercent | 99 | Soft-clips Ca traces at the 99th percentile before rendering. Prevents one very active ROI from washing out all others. |
| GlobalScale | true | `true`: divide all traces by the global max across all ROIs and frames. `false`: normalise each ROI to its own peak. |

### Encoder

| Parameter | Default | Notes |
|---|---|---|
| Quality | 95 | MPEG-4 quality, 1–100. 95 is visually lossless for most uses. |
| Profile | MPEG-4 | `MPEG-4` is recommended. `Uncompressed AVI` gives largest files but is lossless. |

---

## Spiketimes format

The loader accepts any of the following structures inside the `.mat` file.
It searches up to 3 levels deep automatically.

### Cell array (recommended)
```matlab
spiketimes = {[t1_1, t1_2, ...],   % unit 1 spike times in seconds
              [t2_1, t2_2, ...],   % unit 2
              ...};
```

### Struct array
```matlab
spiketimes(1).spks = [t1_1, t1_2, ...];
spiketimes(2).spks = [t2_1, t2_2, ...];
```

### Scalar struct with cell field
```matlab
spiketimes.spks = {[t1_1, ...], [t2_1, ...], ...};
```

### Scalar struct with matrix field
```matlab
spiketimes.spks = [N_units × N_max_spikes];  % NaN-padded rows
```

Field name aliases searched: `spks`, `t`, `times`, `spike_times`, `spikeTimes`.

All times must be in **seconds**.
