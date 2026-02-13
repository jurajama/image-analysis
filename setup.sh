#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

echo "=== Parking Lot Car Detector - Setup ==="
echo

# --- System dependencies ---
echo "[1/3] Installing system dependencies..."
sudo apt update -qq
sudo apt install -y python3 python3-venv libgl1
echo

# --- Python virtual environment ---
echo "[2/3] Creating Python virtual environment..."
if [ -d "$VENV_DIR" ]; then
    echo "  Virtual environment already exists at $VENV_DIR, skipping."
else
    python3 -m venv "$VENV_DIR"
    echo "  Created virtual environment at $VENV_DIR"
fi
echo

# --- Python packages ---
echo "[3/3] Installing Python packages..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install ultralytics opencv-python-headless pillow flask
echo

echo "=== Setup complete ==="
echo
echo "Usage:"
echo "  source $VENV_DIR/bin/activate"
echo "  python $SCRIPT_DIR/detect_cars.py <image_path>"
