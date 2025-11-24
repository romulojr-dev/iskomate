import numpy as np
import tensorflow.lite as tflite 
import cv2
import firebase_admin
from firebase_admin import credentials, db
from flask import Flask, request, jsonify
import mediapipe as mp
import time
import os
import socket # Used to find your IP address automatically

# ==========================================
# CONFIGURATION
# ==========================================
# Make sure these two files are in the SAME folder as this script
MODEL_PATH = "./engagement_model_quantized.tflite" 
KEY_PATH = "serviceAccountKey.json"
FIREBASE_URL = "https://iskomate-f149c-default-rtdb.asia-southeast1.firebasedatabase.app/"

# ==========================================
# 1. FIREBASE SETUP
# ==========================================
if not firebase_admin._apps:
    cred = credentials.Certificate(KEY_PATH)
    firebase_admin.initialize_app(cred, {
        'databaseURL': FIREBASE_URL
    })

# References to database locations
firebase_stats_ref = db.reference('aiResult/engagement_stats')
firebase_config_ref = db.reference('server_config')

# ==========================================
# 2. AUTOMATIC IP CONFIGURATION
# ==========================================
def update_ip_on_firebase():
    """
    Finds the laptop's current Wi-Fi IP address and uploads it to Firebase.
    The Raspberry Pi will read this to know where to send images.
    """
    try:
        # We connect to a public DNS (Google's 8.8.8.8) to determine our local IP.
        # We don't actually send data, just check the routing.
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        my_ip = s.getsockname()[0]
        s.close()
        
        # Construct the full URL
        full_url = f"http://{my_ip}:5000/process_frame"
        
        print("------------------------------------------------")
        print(f"--> DETECTED LOCAL IP: {my_ip}")
        print(f"--> UPLOADING TO FIREBASE: {full_url}")
        print("------------------------------------------------")
        
        # Save to Firebase so the RPi can read it
        firebase_config_ref.set({
            "active_url": full_url,
            "last_updated": int(time.time())
        })
        
    except Exception as e:
        print(f"CRITICAL ERROR: Could not find IP or update Firebase: {e}")

# ==========================================
# 3. LOAD MODELS
# ==========================================
print("Loading MediaPipe Face Detection...")
mp_face_detection = mp.solutions.face_detection
face_detection = mp_face_detection.FaceDetection(min_detection_confidence=0.5)

print(f"Loading TFLite Model from {MODEL_PATH}...")
try:
    interpreter = tflite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    print("Model Loaded Successfully!")
except Exception as e:
    print(f"CRITICAL ERROR: Could not load model. Is '{MODEL_PATH}' in this folder? {e}")
    exit()

def softmax(x):
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum()

# ==========================================
# 4. FLASK SERVER
# ==========================================
app = Flask(__name__)

@app.route('/')
def home():
    return "Iskomate Local Laptop Server is Running!"

@app.route('/process_frame', methods=['POST'])
def process_frame():
    try:
        # Check if image was sent
        if 'image' not in request.files:
            return jsonify({"status": "no_image"}), 400
            
        file = request.files['image']
        
        # Decode Image
        npimg = np.frombuffer(file.read(), np.uint8)
        frame = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

        if frame is None:
             return jsonify({"status": "error", "message": "Could not decode image"}), 400

        # Face Detection (MediaPipe)
        # Convert BGR (OpenCV) to RGB (MediaPipe)
        results = face_detection.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))

        if not results.detections:
            # Update Firebase even if no face, so app knows system is alive
            firebase_stats_ref.update({"status": "No Face Detected", "timestamp": int(time.time()*1000)})
            print("No face detected")
            return jsonify({"status": "no_face"})

        # Crop Face logic
        h, w, _ = frame.shape
        bboxC = results.detections[0].location_data.relative_bounding_box
        x, y = int(bboxC.xmin * w), int(bboxC.ymin * h)
        w_box, h_box = int(bboxC.width * w), int(bboxC.height * h)
        
        # Ensure crop is within image bounds
        x, y = max(0, x), max(0, y)
        face_img = frame[y:y+h_box, x:x+w_box]

        if face_img.size == 0: return jsonify({"status": "crop_fail"})

        # AI Inference (TFLite)
        target_h, target_w = input_details[0]['shape'][1], input_details[0]['shape'][2]
        resized_face = cv2.resize(face_img, (target_w, target_h))
        
        input_data = np.expand_dims(resized_face, axis=0)
        
        # Handle Float vs Int models automatically
        if input_details[0]['dtype'] == np.float32:
            input_data = np.float32(input_data)
            # If your model expects 0-1 normalization, uncomment the next line:
            # input_data = input_data / 255.0 

        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()
        output_data = interpreter.get_tensor(output_details[0]['index'])[0]
        scores = softmax(output_data)

        # Update Results to Firebase
        data = {
            "highly_engaged": float(scores[0] * 100),
            "engaged": float(scores[1] * 100),
            "barely_engaged": float(scores[2] * 100),
            "not_engaged": float(scores[3] * 100),
            "timestamp": int(time.time() * 1000),
            "status": "Tracking"
        }
        firebase_stats_ref.set(data)
        
        # Local Debug Print
        print(f"Processed: Engaged {data['engaged']:.1f}%")
        
        return jsonify({"status": "success", "data": data})

    except Exception as e:
        print(f"Error processing frame: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    # 1. Update Firebase with our IP so the Pi can find us
    update_ip_on_firebase()
    
    # 2. Start the Server
    # host='0.0.0.0' allows external devices (Pi) to connect
    app.run(host='0.0.0.0', port=5000)