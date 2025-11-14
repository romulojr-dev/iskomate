from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit
import cv2
import base64
import threading
import json
from aiortc import RTCPeerConnection, RTCSessionDescription, VideoStreamTrack
from aiortc.contrib.media import MediaRelay
import asyncio
import socketio
import requests

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key'
socketio_server = SocketIO(app, cors_allowed_origins="*")

# Store active sessions
sessions = {}
relay = MediaRelay()

# Socket.IO client to connect to laptop server
laptop_client = socketio.Client()
LAPTOP_SERVER_URL = 'http://100.105.15.120:6001'

class CameraVideoStreamTrack(VideoStreamTrack):
    def __init__(self):
        super().__init__()
        self.cap = cv2.VideoCapture(0)  # Use Raspberry Pi camera
        
    async def recv(self):
        pts, time_base = await self.next_timestamp()
        ret, frame = self.cap.read()
        if ret:
            return av.VideoFrame.from_ndarray(frame, format="bgr24")

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "online", "device": "raspberry_pi"})

@app.route('/create_session', methods=['POST'])
def create_session():
    """Create new session with unique ID"""
    session_id = request.json.get('session_id')
    sessions[session_id] = {
        'active': False,
        'peer_connection': None,
        'processing': False
    }
    return jsonify({"success": True, "session_id": session_id})

@socketio_server.on('offer')
def handle_offer(data):
    """Handle WebRTC offer from Flutter app"""
    session_id = data.get('session_id')
    offer_sdp = data.get('sdp')
    
    async def create_answer():
        pc = RTCPeerConnection()
        sessions[session_id]['peer_connection'] = pc
        
        # Add camera track
        camera_track = CameraVideoStreamTrack()
        pc.addTrack(camera_track)
        
        # Set remote description
        await pc.setRemoteDescription(RTCSessionDescription(
            sdp=offer_sdp['sdp'],
            type=offer_sdp['type']
        ))
        
        # Create answer
        answer = await pc.createAnswer()
        await pc.setLocalDescription(answer)
        
        return {
            'sdp': pc.localDescription.sdp,
            'type': pc.localDescription.type
        }
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    answer = loop.run_until_complete(create_answer())
    
    emit('answer', {'session_id': session_id, 'sdp': answer})

@socketio_server.on('start_processing')
def handle_start_processing(data):
    """Start sending video to laptop for processing"""
    session_id = data.get('session_id')
    
    if session_id in sessions:
        sessions[session_id]['processing'] = True
        
        # Connect to laptop server
        try:
            laptop_client.connect(LAPTOP_SERVER_URL)
            laptop_client.emit('register_raspi', {'session_id': session_id})
            
            # Start video forwarding thread
            thread = threading.Thread(
                target=forward_video_to_laptop,
                args=(session_id,)
            )
            thread.start()
            
            emit('processing_started', {'session_id': session_id})
        except Exception as e:
            emit('error', {'message': str(e)})

def forward_video_to_laptop(session_id):
    """Forward video frames to laptop for processing"""
    cap = cv2.VideoCapture(0)
    
    while sessions[session_id]['processing']:
        ret, frame = cap.read()
        if ret:
            # Encode frame to base64
            _, buffer = cv2.imencode('.jpg', frame)
            frame_base64 = base64.b64encode(buffer).decode('utf-8')
            
            # Send to laptop server
            laptop_client.emit('video_frame', {
                'session_id': session_id,
                'frame': frame_base64
            })
        
        # Control frame rate (e.g., 15 fps)
        cv2.waitKey(66)
    
    cap.release()

@laptop_client.on('processed_frame')
def handle_processed_frame(data):
    """Receive processed frame from laptop and send to Flutter"""
    session_id = data.get('session_id')
    socketio_server.emit('processed_video', data, room=session_id)

@laptop_client.on('detection_results')
def handle_detection_results(data):
    """Receive detection results from laptop"""
    session_id = data.get('session_id')
    engaged_count = data.get('engaged_count', 0)
    disengaged_count = data.get('disengaged_count', 0)
    
    # Calculate percentages
    total = engaged_count + disengaged_count
    if total > 0:
        engaged_percent = (engaged_count / total) * 100
        disengaged_percent = (disengaged_count / total) * 100
    else:
        engaged_percent = 0
        disengaged_percent = 0
    
    # Send to Flutter app
    socketio_server.emit('results', {
        'session_id': session_id,
        'engaged_percent': engaged_percent,
        'disengaged_percent': disengaged_percent,
        'engaged_count': engaged_count,
        'disengaged_count': disengaged_count
    }, room=session_id)
    
    # Trigger alert if disengaged detected
    if disengaged_count > 0:
        trigger_disengagement_alert(disengaged_count)

def trigger_disengagement_alert(count):
    """Trigger alert on Raspberry Pi (buzzer, LED, etc.)"""
    # Example: Control GPIO
    # GPIO.output(BUZZER_PIN, GPIO.HIGH)
    print(f"⚠️ ALERT: {count} disengaged students detected!")

@socketio_server.on('stop_processing')
def handle_stop_processing(data):
    """Stop processing"""
    session_id = data.get('session_id')
    if session_id in sessions:
        sessions[session_id]['processing'] = False
        laptop_client.disconnect()
        emit('processing_stopped', {'session_id': session_id})

if __name__ == '__main__':
    socketio_server.run(app, host='0.0.0.0', port=5000, debug=True)