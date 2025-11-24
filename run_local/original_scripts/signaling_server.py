# original: signaling_server.py

import asyncio
import websockets
import json
import logging

logging.basicConfig(level=logging.INFO)

# State variables
CAMERA_SOCKET = None
VIEWER_SOCKET = None
CACHED_OFFER = None
CACHED_CANDIDATES = []

async def handler(websocket):
    global CAMERA_SOCKET, VIEWER_SOCKET, CACHED_OFFER, CACHED_CANDIDATES

    logging.info("New client connected.")

    try:
        async for message in websocket:
            data = json.loads(message)
            msg_type = data.get("type")

            # === 1. CAMERA REGISTRATION ===
            if msg_type == "camera_join":
                logging.info(">>> CAMERA REGISTERED <<<")
                CAMERA_SOCKET = websocket

                # If we have mail waiting for the camera, deliver it now!
                if CACHED_OFFER:
                    logging.info("Delivering missed OFFER to Camera...")
                    await websocket.send(json.dumps(CACHED_OFFER))
                    for cand in CACHED_CANDIDATES:
                        await websocket.send(json.dumps(cand))

            # === 2. HANDLING OFFERS (From Phone) ===
            elif msg_type == "offer":
                logging.info("Received OFFER from Viewer.")
                VIEWER_SOCKET = websocket
                CACHED_OFFER = data # Save it
                CACHED_CANDIDATES = [] # Clear old candidates

                # If Camera is already here, forward immediately
                if CAMERA_SOCKET:
                    await CAMERA_SOCKET.send(message)
                else:
                    logging.info("Camera offline. Storing OFFER in mailbox.")

            # === 3. HANDLING ANSWERS (From Pi) ===
            elif msg_type == "answer":
                logging.info("Received ANSWER from Camera. Forwarding to Viewer.")
                if VIEWER_SOCKET:
                    await VIEWER_SOCKET.send(message)

            # === 4. HANDLING ICE CANDIDATES ===
            elif msg_type == "candidate":
                # If it's from the Viewer (Phone), save it for the Camera
                if websocket == VIEWER_SOCKET:
                    if CAMERA_SOCKET:
                        await CAMERA_SOCKET.send(message)
                    else:
                        CACHED_CANDIDATES.append(data)

                # If it's from the Camera, send to Viewer
                elif websocket == CAMERA_SOCKET:
                    if VIEWER_SOCKET:
                        await VIEWER_SOCKET.send(message)

    except websockets.exceptions.ConnectionClosed:
        logging.info("Connection closed.")
    except Exception as e:
        logging.error(f"Error: {e}")
    finally:
        # Cleanup
        if websocket == CAMERA_SOCKET:
            logging.info("Camera disconnected.")
            CAMERA_SOCKET = None
        elif websocket == VIEWER_SOCKET:
            logging.info("Viewer disconnected. Clearing Mailbox.")
            VIEWER_SOCKET = None
            CACHED_OFFER = None # Mail is invalid if sender leaves
            CACHED_CANDIDATES = []

async def main():
    # Listen on all interfaces (0.0.0.0) so external devices can connect
    logging.info("Smart Signaling Server starting on 0.0.0.0:8765")
    async with websockets.serve(handler, "0.0.0.0", 8765, ping_interval=None):
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())