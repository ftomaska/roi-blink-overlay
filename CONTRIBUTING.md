# Contributing

Contributions welcome — bug reports, feature requests, and pull requests all appreciated.

## Reporting bugs

Please include:
- OS and Python/MATLAB version
- Full error traceback from the log panel
- What file formats you were loading (Suite2p version, `.mat` version if applicable)

## Development setup

```bash
git clone https://github.com/YOUR_USERNAME/roi-blink-overlay
cd roi-blink-overlay/python
bash setup_env.sh
conda activate roi_blink
python roi_blink_overlay.py
```

## Code style

- Python: PEP 8, 100-char line limit. Private methods prefixed with `_`.
- MATLAB: camelCase methods, section comments with `% ──` dividers.
- Keep the rendering engine (top of `roi_blink_overlay.py`) free of tkinter imports
  so it can be used headlessly.

## Adding support for a new file format

See [`docs/development.md`](docs/development.md) for the extension points.

## Pull request checklist

- [ ] Tested on at least one real Suite2p dataset
- [ ] No hardcoded paths
- [ ] New parameters documented in `docs/parameters.md`
- [ ] CHANGELOG.md updated
