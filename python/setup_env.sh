#!/usr/bin/env bash
# =============================================================================
#  ROI Blink Overlay — Environment Setup
#  Run this script once to create and populate the conda/venv environment.
#
#  Usage (pick one):
#    bash setup_env.sh          # uses conda if available, otherwise venv
#    bash setup_env.sh --venv   # force plain Python venv
#    bash setup_env.sh --conda  # force conda
# =============================================================================

ENV_NAME="roi_blink"
PYTHON_VERSION="3.11"

# ── Detect mode ───────────────────────────────────────────────────────────────
USE_CONDA=false
USE_VENV=false

if [[ "$1" == "--conda" ]]; then
    USE_CONDA=true
elif [[ "$1" == "--venv" ]]; then
    USE_VENV=true
elif command -v conda &>/dev/null; then
    USE_CONDA=true
else
    USE_VENV=true
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   ROI Blink Overlay — Environment Setup          ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── CONDA path ────────────────────────────────────────────────────────────────
if $USE_CONDA; then
    echo "▶  Using conda  (env name: $ENV_NAME)"
    echo ""

    # Check conda is available
    if ! command -v conda &>/dev/null; then
        echo "✗  conda not found. Install Miniconda from:"
        echo "   https://docs.conda.io/en/latest/miniconda.html"
        echo "   Then re-run this script."
        exit 1
    fi

    # Remove old env if it exists
    if conda env list | grep -q "^${ENV_NAME} "; then
        echo "   Existing env '$ENV_NAME' found — removing it first..."
        conda env remove -n "$ENV_NAME" -y
    fi

    echo "▶  Creating conda env '$ENV_NAME' with Python $PYTHON_VERSION..."
    conda create -n "$ENV_NAME" python="$PYTHON_VERSION" -y

    echo ""
    echo "▶  Installing packages..."
    conda run -n "$ENV_NAME" pip install \
        numpy>=1.21 \
        scipy>=1.7 \
        "Pillow>=9.0" \
        "imageio[ffmpeg]>=2.28" \
        imageio-ffmpeg>=0.4.7 \
        scikit-image>=0.19

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║   ✓  Done!  Activate with:                       ║"
    echo "║                                                  ║"
    echo "║   conda activate $ENV_NAME                       ║"
    echo "║   python roi_blink_overlay.py                    ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""

# ── VENV path ─────────────────────────────────────────────────────────────────
else
    echo "▶  Using Python venv  (folder: ./$ENV_NAME)"
    echo ""

    # Check python3 is available
    if ! command -v python3 &>/dev/null; then
        echo "✗  python3 not found."
        echo "   Install from https://www.python.org/downloads/"
        exit 1
    fi

    PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    echo "   Python version: $PY_VER"

    # Remove old venv if it exists
    if [ -d "$ENV_NAME" ]; then
        echo "   Existing venv '$ENV_NAME' found — removing it first..."
        rm -rf "$ENV_NAME"
    fi

    echo "▶  Creating venv '$ENV_NAME'..."
    python3 -m venv "$ENV_NAME"

    echo "▶  Installing packages..."
    "$ENV_NAME/bin/pip" install --upgrade pip
    "$ENV_NAME/bin/pip" install \
        "numpy>=1.21" \
        "scipy>=1.7" \
        "Pillow>=9.0" \
        "imageio[ffmpeg]>=2.28" \
        "imageio-ffmpeg>=0.4.7" \
        "scikit-image>=0.19"

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║   ✓  Done!  Activate with:                       ║"
    echo "║                                                  ║"
    echo "║   source $ENV_NAME/bin/activate                  ║"
    echo "║   python roi_blink_overlay.py                    ║"
    echo "║                                                  ║"
    echo "║   (Windows: $ENV_NAME\\Scripts\\activate)          ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
fi
