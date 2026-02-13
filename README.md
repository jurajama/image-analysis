# Parking Lot Car Detector

Detects and counts vehicles in parking lot images using YOLOv8 object detection.

## Prerequisites

- Ubuntu 24.04 (x86_64)
- Python 3.12+
- sudo access (for system package installation)

## Installation

Run the setup script:

```bash
chmod +x setup.sh
./setup.sh
```

This will:
1. Install system dependencies (`python3`, `python3-venv`, `libgl1`)
2. Create a Python virtual environment in `./venv`
3. Install Python packages (`ultralytics`, `opencv-python-headless`, `pillow`, `flask`)

On first run, the YOLOv8 medium model (`yolov8m.pt`, ~50MB) is downloaded automatically.

## Usage

### Command Line

Activate the virtual environment and run the detection script:

```bash
source venv/bin/activate
python detect_cars.py <image_path>
```

If no image path is provided, it defaults to `20260213_115233.jpg`.

#### Example

```bash
source venv/bin/activate
python detect_cars.py parking_photo.jpg
```

Output:

```
Detected 3 vehicle(s):

  1. car (confidence: 92.4%) at (1186, 1236, 1767, 1680)
  2. car (confidence: 90.8%) at (1987, 943, 2444, 1257)
  3. car (confidence: 84.6%) at (2310, 826, 2745, 1079)

Annotated image saved to: parking_photo_detected.jpg
```

An annotated copy of the image with bounding boxes is saved as `<filename>_detected.jpg`.

### Web Server

A browser-based interface is also available via `web_server.py`:

```bash
source venv/bin/activate
python web_server.py
```

The server starts on port 8080. Open `http://localhost:8080` in a browser to upload an image for detection. The result page displays the annotated image with bounding boxes and a list of detected vehicles.

You can also test with curl:

```bash
curl -X POST -F "image=@20260213_115233.jpg" http://localhost:8080/detect
```

Uploaded images are saved to `uploads/` and annotated results to `results/`.

## Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| Model | `yolov8m.pt` | YOLOv8 medium — good balance of speed and accuracy |
| Confidence threshold | 0.60 | Minimum detection confidence to filter false positives |
| Vehicle classes | car, bus, truck | COCO dataset class IDs 2, 5, 7 |

To adjust the confidence threshold, edit `CONFIDENCE_THRESHOLD` in `detect_cars.py` or `web_server.py`.

## Project Structure

```
.
├── README.md              # This file
├── setup.sh               # Automated setup script
├── detect_cars.py         # Command-line detection script
├── web_server.py          # Web-based detection server (Flask, port 8080)
└── venv/                  # Python virtual environment (created by setup.sh)
```
