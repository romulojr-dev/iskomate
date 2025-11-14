from flask import Flask, request
from flask_socketio import SocketIO, emit
import cv2
import base64
import numpy as np
from ultralytics import YOLO
import threading
import time

app = Flask(__name__)
app.config['SECRET_KEY'] = 'laptop-server-key'
socketio_server = SocketIO(app, cors_allowed_origins="*")

# Load YOLO model (use your trained engagement detection model)
model = YOLO("C:\Users\John Gwen Isaac\Downloads\best.pt")

# Store connected Raspberry Pis
connected_raspis = {}

@socketio_server.on('register_raspi')
def handle_register(data):
    """Register Raspberry Pi connection"""
    session_id = data.get('session_id')
    connected_raspis[session_id] = {
        'sid': request.sid,
        'last_frame_time': time.time()
    }
    print(f"✅ Raspberry Pi registered: {session_id}")

@socketio_server.on('video_frame')
def handle_video_frame(data):
    """Process video frame from Raspberry Pi"""
    session_id = data.get('session_id')
    frame_base64 = data.get('frame')
    
    # Check if session exists
    if session_id not in connected_raspis:
        print(f"⚠️ Unknown session: {session_id}")
        return
    
    # Decode frame
    frame_bytes = base64.b64decode(frame_base64)
    frame_array = np.frombuffer(frame_bytes, dtype=np.uint8)
    frame = cv2.imdecode(frame_array, cv2.IMREAD_COLOR)
    
    # Process with YOLO
    results = model(frame, conf=0.5)
    
    # Parse results
    engaged_count = 0
    disengaged_count = 0
    
    for result in results:
        boxes = result.boxes
        for box in boxes:
            # Get coordinates
            x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
            conf = box.conf[0].cpu().numpy()
            cls = int(box.cls[0].cpu().numpy())
            
            # Get class name
            class_name = model.names[cls]
            
            # Count engaged/disengaged
            if class_name.lower() == 'engaged':
                engaged_count += 1
                color = (0, 255, 0)  # Green
            else:  # disengaged
                disengaged_count += 1
                color = (0, 0, 255)  # Red
            
            # Draw bounding box
            cv2.rectangle(frame, (int(x1), int(y1)), (int(x2), int(y2)), color, 2)
            
            # Draw label
            label = f"{class_name}: {conf:.2f}"
            cv2.putText(frame, label, (int(x1), int(y1) - 10),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
    
    # Encode processed frame
    _, buffer = cv2.imencode('.jpg', frame)
    processed_frame_base64 = base64.b64encode(buffer).decode('utf-8')
    
    # Send processed frame back to Raspberry Pi
    socketio_server.emit('processed_frame', {
        'session_id': session_id,
        'frame': processed_frame_base64
    }, room=connected_raspis[session_id]['sid'])
    
    # Send detection results
    socketio_server.emit('detection_results', {
        'session_id': session_id,
        'engaged_count': engaged_count,
        'disengaged_count': disengaged_count,
        'timestamp': time.time()
    }, room=connected_raspis[session_id]['sid'])

@socketio_server.on('disconnect')
def handle_disconnect():
    """Handle Raspberry Pi disconnection"""
    for session_id, info in list(connected_raspis.items()):
        if info['sid'] == request.sid:
            del connected_raspis[session_id]
            print(f"❌ Raspberry Pi disconnected: {session_id}")

if __name__ == '__main__':
    socketio_server.run(app, host='0.0.0.0', port=6001, debug=True, allow_unsafe_werkzeug=True)
