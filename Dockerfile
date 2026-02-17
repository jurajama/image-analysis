FROM python:3.12-slim

# Install system dependencies required by OpenCV
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
RUN pip install --no-cache-dir \
        ultralytics \
        opencv-python-headless \
        pillow \
        flask

# Pre-download the YOLOv8 model so it is baked into the image
# and not fetched at container startup
RUN python -c "from ultralytics import YOLO; YOLO('yolov8m.pt')"

# Copy application source
COPY web_server.py .

EXPOSE 8080

CMD ["python", "web_server.py"]
