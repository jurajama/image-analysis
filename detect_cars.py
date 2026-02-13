from ultralytics import YOLO
from pathlib import Path
import sys

# Load pre-trained YOLOv8 nano model (downloads automatically on first run)
model = YOLO("yolov8m.pt")

# Image path from command line argument or default
image_path = sys.argv[1] if len(sys.argv) > 1 else "20260213_115233.jpg"

# Confidence threshold to filter out false positives
CONFIDENCE_THRESHOLD = 0.60

# Run inference
results = model(image_path, conf=CONFIDENCE_THRESHOLD)

# COCO class IDs for vehicles: 2=car, 5=bus, 7=truck
vehicle_classes = {2: "car", 5: "bus", 7: "truck"}

# Process detections
vehicles = []
for result in results:
    for box in result.boxes:
        cls_id = int(box.cls[0])
        if cls_id in vehicle_classes:
            confidence = float(box.conf[0])
            label = vehicle_classes[cls_id]
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            vehicles.append({
                "type": label,
                "confidence": confidence,
                "bbox": (int(x1), int(y1), int(x2), int(y2))
            })

# Print results
print(f"\nDetected {len(vehicles)} vehicle(s):\n")
for i, v in enumerate(vehicles, 1):
    print(f"  {i}. {v['type']} (confidence: {v['confidence']:.1%}) at {v['bbox']}")

# Save annotated image
output_path = Path(image_path).stem + "_detected.jpg"
results[0].save(output_path)
print(f"\nAnnotated image saved to: {output_path}")
