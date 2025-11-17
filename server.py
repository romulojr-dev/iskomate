import cv2
import socket
import numpy as np
import time
import struct
import threading
from pynput import keyboard # Handles non-blocking keyboard input

# --- Configuration ---
HOST = '0.0.0.0' # Laptop listens on this for incoming video (Port 5555)
PORT = 5555      # Video stream port
FRAME_SIZE_HEADER = 4 


# --- New Configuration for Command Client (Laptop connects to Pi) ---
# *** IMPORTANT: Use your Raspberry Pi's actual local IP address ***
# Based on your previous successful bind, use the Pi's IP: 192.168.254.115
PI_IP = "100.74.50.99" 
COMMAND_PORT = 5556

# Global control variables
command_socket = None
keyboard_listener = None
is_running = True

# --- Command Helper Function ---
def send_command_to_pi(command):
    """Sends a single command ('1' or '2') to the Pi's command server."""
    global command_socket
    if command_socket:
        try:
            command_socket.sendall(command.encode())
            # print(f"[COMMAND] Sent command: {command}") # Optional: uncomment for feedback
        except Exception as e:
            print(f"Error sending command: {e}")

# --- Keyboard Listener Functions (using pynput) ---
def on_press(key):
    """Called when a key is pressed."""
    global is_running
    try:
        char = key.char
        if char == '1' or char == '2':
            send_command_to_pi(char)
        elif char == 'q':
            is_running = False
            return False # Stops the keyboard listener
    except AttributeError:
        # Ignore special keys
        pass

def start_keyboard_listener():
    """Starts the keyboard listener thread."""
    global keyboard_listener
    keyboard_listener = keyboard.Listener(on_press=on_press)
    keyboard_listener.start()
    print("Keyboard listener active. Press '1' or '2' to send commands, 'q' to quit.")

# --- Socket Helper Function ---
def recvall(sock, count):
    """Receives a specific number of bytes from the socket."""
    buf = b''
    while count:
        try:
            newbuf = sock.recv(count)
            if not newbuf: return None
            buf += newbuf
            count -= len(newbuf)
        except Exception:
            return None
    return buf

# --- Main Server Logic ---
def main_server():
    global command_socket, is_running
    
    # -------------------------------------------------------------
    # 1. SETUP COMMAND CLIENT (Laptop connects to Pi Server on 5556)
    # -------------------------------------------------------------
    try:
        command_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        # Laptop connects to the Pi's IP and command port
        command_socket.connect((PI_IP, COMMAND_PORT)) 
        print(f"Command Client connected to Pi at {PI_IP}:{COMMAND_PORT}")
        start_keyboard_listener()
    except ConnectionRefusedError:
        print(f"Error: Could not connect to Pi Command Server at {PI_IP}:{COMMAND_PORT}.")
        print("ACTION: Ensure 'pi_command_server.py' is running on the Pi!")
        
    # -------------------------------------------------------------
    # 2. SETUP VIDEO SERVER (Laptop listens for Pi Client on 5555)
    # -------------------------------------------------------------
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server_socket.bind((HOST, PORT))
    except Exception as e:
        print(f"Error binding video server socket: {e}. Is port {PORT} in use?")
        is_running = False
        
    server_socket.listen(1)

    print(f"Video Server is listening on port {PORT}. Waiting for Pi connection...")

    # Wait for the Pi video client connection (BLOCKING)
    try:
        conn, addr = server_socket.accept()
        print(f"Video connection established with: {addr}")
    except Exception as e:
        if is_running:
            print(f"Error establishing video connection: {e}")
            is_running = False
        
    # -------------------------------------------------------------
    # 3. VIDEO PROCESSING LOOP
    # -------------------------------------------------------------
    try:
        while is_running:
            # Receive size header
            size_data = recvall(conn, FRAME_SIZE_HEADER)
            if size_data is None: break
                
            frame_size = int.from_bytes(size_data, 'little')
            
            # Receive frame data
            encoded_image_bytes = recvall(conn, frame_size)
            if encoded_image_bytes is None: break

            nparr = np.frombuffer(encoded_image_bytes, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if frame is not None:
                # DISPLAY & KEYBOARD CHECK
                current_time = time.strftime("%H:%M:%S", time.localtime())
                cv2.putText(frame, 
                            f"Frame Received: {current_time}", 
                            (10, 30), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

                cv2.imshow("Live Pi Webcam Feed (TCP Server)", frame)
                
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    is_running = False
                    break
        
    except Exception as e:
        if is_running:
            print(f"An error occurred in the video loop: {e}")

    finally:
        # Cleanup
        print("Starting cleanup...")
        if keyboard_listener and keyboard_listener.running:
            keyboard_listener.stop()
        cv2.destroyAllWindows()
        if 'conn' in locals(): conn.close()
        server_socket.close()
        if command_socket: command_socket.close()
        print("Server cleanup complete.")

if __name__ == "__main__":
    main_server()