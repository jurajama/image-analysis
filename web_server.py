import os
import uuid
from flask import Flask, request, send_from_directory
from ultralytics import YOLO

app = Flask(__name__)

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
RESULT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(RESULT_DIR, exist_ok=True)

CONFIDENCE_THRESHOLD = 0.60
VEHICLE_CLASSES = {2: "car", 5: "bus", 7: "truck"}

print("Loading YOLO model...")
model = YOLO("yolov8m.pt")
print("Model loaded.")

UPLOAD_FORM = """
<h2>Upload an image for vehicle detection</h2>
<form method="post" action="/detect" enctype="multipart/form-data">
  <input type="file" name="image" accept="image/*" required>
  <button type="submit">Detect Vehicles</button>
</form>
"""


@app.route("/")
def index():
    return f"<html><body>{UPLOAD_FORM}</body></html>"


@app.route("/detect", methods=["POST"])
def detect():
    if "image" not in request.files:
        return "<html><body><p>No image uploaded.</p>" + UPLOAD_FORM + "</body></html>", 400

    file = request.files["image"]
    if file.filename == "":
        return "<html><body><p>No file selected.</p>" + UPLOAD_FORM + "</body></html>", 400

    # Save uploaded file with unique name
    ext = os.path.splitext(file.filename)[1] or ".jpg"
    unique_name = uuid.uuid4().hex + ext
    upload_path = os.path.join(UPLOAD_DIR, unique_name)
    file.save(upload_path)

    # Run detection
    results = model(upload_path, conf=CONFIDENCE_THRESHOLD)

    # Extract vehicle detections
    vehicles = []
    for result in results:
        for box in result.boxes:
            cls_id = int(box.cls[0])
            if cls_id in VEHICLE_CLASSES:
                confidence = float(box.conf[0])
                label = VEHICLE_CLASSES[cls_id]
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                vehicles.append({
                    "type": label,
                    "confidence": confidence,
                    "bbox": (int(x1), int(y1), int(x2), int(y2)),
                })

    # Save annotated image
    result_name = "result_" + unique_name
    result_path = os.path.join(RESULT_DIR, result_name)
    results[0].save(result_path)

    # Build result HTML
    vehicle_list = ""
    for i, v in enumerate(vehicles, 1):
        vehicle_list += f"<li>{v['type']} (confidence: {v['confidence']:.1%}) at {v['bbox']}</li>"

    html = f"""<html><body>
<h2>Detection Results</h2>
<p>Detected <strong>{len(vehicles)}</strong> vehicle(s):</p>
<ol>{vehicle_list}</ol>
<img src="/result/{result_name}" style="max-width:100%;">
<hr>
{UPLOAD_FORM}
</body></html>"""
    return html


@app.route("/result/<filename>")
def result_image(filename):
    return send_from_directory(RESULT_DIR, filename)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
