import asyncio
import json
import cv2
import websockets
import numpy as np
import sys
from aiortc import RTCPeerConnection, RTCSessionDescription, VideoStreamTrack
from aiortc.contrib.media import MediaRelay

# !!! PI IP ADDRESS !!!
PI_URL = "ws://100.74.50.99:8765"

# The Relay allows us to duplicate the video stream efficiently
relay = MediaRelay()
pi_video_track = None

async def run_ai_processing(track):
    print("AI Loop Started")
    while True:
        try:
            frame = await track.recv()
            # Convert to OpenCV image
            img = frame.to_ndarray(format="bgr24")
            
            # === YOUR AI MODEL GOES HERE ===
            # model.predict(img)
            
            cv2.imshow("Laptop AI View", img)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
        except Exception:
            break

# --- This handles the Flutter App connecting to the Laptop ---
async def handle_app(websocket):
    print("Flutter App Connected to Laptop!")
    pc = RTCPeerConnection()
    
    # Give the App a COPY of the Pi's video
    if pi_video_track:
        pc.addTrack(relay.subscribe(pi_video_track))

    try:
        async for message in websocket:
            data = json.loads(message)
            if data["type"] == "offer":
                await pc.setRemoteDescription(RTCSessionDescription(sdp=data["sdp"], type=data["type"]))
                answer = await pc.createAnswer()
                await pc.setLocalDescription(answer)
                await websocket.send(json.dumps({"type": "answer", "sdp": pc.localDescription.sdp}))
    finally:
        await pc.close()

# --- This connects the Laptop to the Pi ---
async def connect_to_pi():
    global pi_video_track
    pc = RTCPeerConnection()
    
    @pc.on("track")
    def on_track(track):
        print("Receiving Video from Pi...")
        global pi_video_track
        pi_video_track = track
        
        # 1. Feed the AI (using a copy of the track)
        asyncio.ensure_future(run_ai_processing(relay.subscribe(track)))

    async with websockets.connect(PI_URL) as ws:
        print("Connected to Pi.")
        pc.addTransceiver("video", direction="recvonly")
        offer = await pc.createOffer()
        await pc.setLocalDescription(offer)
        await ws.send(json.dumps({"type": "offer", "sdp": pc.localDescription.sdp}))
        
        # Keep connection alive and handle signaling
        async for msg in ws:
            data = json.loads(msg)
            if data["type"] == "answer":
                await pc.setRemoteDescription(RTCSessionDescription(sdp=data["sdp"], type=data["type"]))
            
            # Keep running to serve the app
            await asyncio.Future() 

async def main():
    # Start the server for the App
    server = await websockets.serve(handle_app, "0.0.0.0", 9090)
    print("Laptop Relay Server running on Port 9090")
    
    # Connect to the Pi
    await connect_to_pi()

if __name__ == "__main__":
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(main())