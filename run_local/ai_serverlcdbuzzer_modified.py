import asyncio
import json
import logging
import websockets
import time
import threading
import cv2
import requests
import numpy as np
import os
import RPi.GPIO as GPIO
from av import VideoFrame
from aiortc import RTCPeerConnection, RTCSessionDescription, VideoStreamTrack, RTCConfiguration
from aiortc.sdp import candidate_from_sdp
import firebase_admin
from firebase_admin import credentials, db

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ==========================================
# CONFIGURATION
# ==========================================
SIGNALING_URL = "ws://100.74.50.99:8765"

# DEFAULT TARGET (Hugging Face)
# This is used if the Laptop is not running or WiFi is disconnected.
CLOUD_API_URL = "https://is-ko123-engagement-api.hf.space/process_frame"

# Hardware Config
BUZZER_PIN = 26  # GPIO 26 (Physical Pin 37)
FRAMEBUFFER_DEVICE = "/dev/fb1" # Your LCD Screen
IMAGE_FOLDER = "/home/pi/engagement_images/"

# ==========================================
# 1. HARDWARE SETUP
# ==========================================
try:
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(BUZZER_PIN, GPIO.OUT)
    GPIO.output(BUZZER_PIN, GPIO.LOW)
except Exception as e:
    logger.error(f"GPIO Setup Failed: {e}")

try:
    if not firebase_admin._apps:
        cred = credentials.Certificate("/home/pi/serviceAccountKey.json")
        firebase_admin.initialize_app(cred, {
            'databaseURL': 'https://iskomate-f149c-default-rtdb.asia-southeast1.firebasedatabase.app/'
        })
    firebase_ref = db.reference('aiResult/engagement_stats')
except Exception as e:
    logger.error(f"Firebase Setup Failed: {e}")

# Load Images
status_images = {}
try:
    status_images = {
        "highly": cv2.imread(f"{IMAGE_FOLDER}highly.png"),
        "engaged": cv2.imread(f"{IMAGE_FOLDER}engaged.png"),
        "barely": cv2.imread(f"{IMAGE_FOLDER}barely.png"),
        "not": cv2.imread(f"{IMAGE_FOLDER}not_engaged.png"),
        "default": np.zeros((320, 480, 3), dtype=np.uint8) # Black screen
    }
except Exception as e:
    logger.error(f"Image Load Failed: {e}")

# ==========================================
# 2. FRAMEBUFFER MANAGER (DIRECT WRITE)
# ==========================================
class FramebufferManager:
    def __init__(self):
        self.width = 480
        self.height = 320
        self.device_path = FRAMEBUFFER_DEVICE
        self.latest_state = "default"

        # Buzzer Logic
        self.not_engaged_start_time = 0
        self.is_buzzing = False

        # Start Loops
        threading.Thread(target=self._firebase_listener, daemon=True).start()
        threading.Thread(target=self._display_loop, daemon=True).start()

    def _firebase_listener(self):
        def on_snapshot(event):
            if event.data:
                try:
                    data = event.data
                    scores = {
                        "highly": float(data.get('highly_engaged', 0)),
                        "engaged": float(data.get('engaged', 0)),
                        "barely": float(data.get('barely_engaged', 0)),
                        "not": float(data.get('not_engaged', 0)),
                    }
                    highest_state = max(scores, key=scores.get)
                    self._handle_logic(highest_state)
                except: pass

        if firebase_ref:
            firebase_ref.listen(on_snapshot)

    def _handle_logic(self, state):
        self.latest_state = state

        if state == "not":
            if self.not_engaged_start_time == 0:
                self.not_engaged_start_time = time.time()
            elif time.time() - self.not_engaged_start_time > 10:
                if not self.is_buzzing:
                    threading.Thread(target=self._trigger_alarm).start()
        else:
            self.not_engaged_start_time = 0
            self.is_buzzing = False

    def _trigger_alarm(self):
        self.is_buzzing = True
        for _ in range(3):
            if self.latest_state != "not": break
            GPIO.output(BUZZER_PIN, GPIO.HIGH)
            time.sleep(0.5)
            GPIO.output(BUZZER_PIN, GPIO.LOW)
            time.sleep(0.5)
        time.sleep(5)
        self.is_buzzing = False

    def _display_loop(self):
        """Writes raw pixels to /dev/fb1"""
        logger.info(f"Writing directly to {self.device_path}")

        while True:
            try:
                # Get Image
                img = status_images.get(self.latest_state, status_images["default"])

                if img is not None:
                    # 1. Resize to screen dimensions (480x320)
                    resized = cv2.resize(img, (self.width, self.height))

                    # 2. Convert BGR (OpenCV) to RGB 565 (LCD)
                    # This is the magic math to make colors look right on Pi screens
                    b, g, r = cv2.split(resized)

                    # RGB565 logic: R=5bits, G=6bits, B=5bits
                    r5 = (r >> 3).astype(np.uint16)
                    g6 = (g >> 2).astype(np.uint16)
                    b5 = (b >> 3).astype(np.uint16)

                    # Shift bits to pack into 16-bit integer
                    rgb565 = (r5 << 11) | (g6 << 5) | b5

                    # 3. Write binary data to framebuffer file
                    with open(self.device_path, 'wb') as f:
                        f.write(rgb565.tobytes())

                time.sleep(0.5) # Refresh rate

            except Exception as e:
                logger.error(f"Framebuffer Error: {e}")
                time.sleep(1)

# Start the manager
fb_manager = FramebufferManager()

# ==========================================
# 3. CAMERA MANAGER
# ==========================================
class CameraManager:
    def __init__(self):
        self.cap = cv2.VideoCapture(0)
        if not self.cap.isOpened():
            self.cap = cv2.VideoCapture(2)

        self.current_frame = None
        self.running = True
        self.lock = threading.Lock()
        threading.Thread(target=self._capture_loop, daemon=True).start()

    def _capture_loop(self):
        while self.running:
            ret, frame = self.cap.read()
            if ret:
                with self.lock:
                    self.current_frame = frame
            else:
                time.sleep(0.1)

    def get_frame(self):
        with self.lock:
            if self.current_frame is not None:
                return self.current_frame.copy()
            else:
                return np.zeros((240, 320, 3), dtype=np.uint8)

global_camera = CameraManager()

# ==========================================
# 4. CLOUD UPLOADER (SMART POLLING)
# ==========================================
def cloud_upload_loop():
    global CLOUD_API_URL
    logger.info(f"Cloud Uploader Active. Initial Target: {CLOUD_API_URL}")
    
    last_config_check = 0
    
    while True:
        # --- A. DYNAMIC CONFIG CHECK (Every 5 Seconds) ---
        # Checks if Laptop Server has posted a new IP to Firebase
        if time.time() - last_config_check > 5:
            try:
                ref = db.reference('server_config/active_url')
                new_url = ref.get()
                
                # If we found a URL and it is different from current one
                if new_url and new_url != CLOUD_API_URL:
                    CLOUD_API_URL = new_url
                    logger.info(f"--> NEW SERVER FOUND! Switching Target to: {CLOUD_API_URL}")
            except Exception:
                # Fails silently if no internet/hotspot yet
                pass
            last_config_check = time.time()

        # --- B. UPLOAD FRAME ---
        try:
            frame = global_camera.get_frame()
            if frame is not None:
                # Compress frame (Quality 50 for speed)
                _, img_encoded = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 50])
                
                response = requests.post(
                    CLOUD_API_URL,
                    files={'image': ('frame.jpg', img_encoded.tobytes(), 'image/jpeg')},
                    timeout=2 # Short timeout to prevent freezing
                )
            
            # Limit FPS to ~5 to save bandwidth
            time.sleep(0.2) 
            
        except Exception:
            # If connection fails, wait a bit and retry
            time.sleep(1)

threading.Thread(target=cloud_upload_loop, daemon=True).start()

# ==========================================
# 5. SIGNALING & WEBRTC
# ==========================================
class MyCameraTrack(VideoStreamTrack):
    async def recv(self):
        pts, time_base = await self.next_timestamp()
        frame = global_camera.get_frame()
        video_frame = VideoFrame.from_ndarray(frame, format="bgr24")
        video_frame.pts = pts
        video_frame.time_base = time_base
        return video_frame

pcs = set()

async def run_signaling(websocket):
    await websocket.send(json.dumps({"type": "camera_join"}))
    try:
        async for message in websocket:
            data = json.loads(message)
            if data["type"] == "offer":
                pc = RTCPeerConnection(configuration=RTCConfiguration(iceServers=[]))
                pcs.add(pc)
                pc.addTrack(MyCameraTrack())

                @pc.on("connectionstatechange")
                async def on_connectionstatechange():
                    if pc.connectionState in ["failed", "closed"]:
                        await pc.close()
                        pcs.discard(pc)

                await pc.setRemoteDescription(RTCSessionDescription(sdp=data["sdp"], type=data["type"]))
                answer = await pc.createAnswer()
                await pc.setLocalDescription(answer)
                await asyncio.sleep(1)
                await websocket.send(json.dumps({"type": "answer", "sdp": pc.localDescription.sdp}))

            elif data["type"] == "candidate":
                candidate_info = data["candidate"]
                if candidate_info:
                    candidate = candidate_from_sdp(candidate_info["candidate"])
                    candidate.sdpMid = candidate_info.get("sdpMid")
                    candidate.sdpMLineIndex = candidate_info.get("sdpMLineIndex")
                    for active_pc in pcs: await active_pc.addIceCandidate(candidate)
    except: pass
    finally:
        for pc in pcs: await pc.close()
        pcs.clear()

async def main():
    while True:
        try:
            async with websockets.connect(SIGNALING_URL) as ws: await run_signaling(ws)
        except: await asyncio.sleep(5)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        GPIO.cleanup()