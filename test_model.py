import cv2
from deepface import DeepFace
import numpy as np
import threading
import time

# --- Configuration ---
EMOTIONS_TO_ENGAGEMENT = {
    'happy': 'Engaged',
    'neutral': 'Engaged',
    'surprise': 'Engaged',
    'sad': 'Not Engaged',
    'angry': 'Not Engaged',
    'disgust': 'Not Engaged',
    'fear': 'Not Engaged',
}

VIDEO_SOURCE = 'rtsp://100.74.50.99:8554/mystream' # Use 0 for webcam, or change to your Pi's URL

# --- NEW: Threading and State Variables ---

# This lock prevents race conditions (e.g., trying to read/write the
# status at the exact same time from two threads)
data_lock = threading.Lock()

# We'll run analysis on a copy of the latest frame
latest_frame = None

# These variables will be shared between our threads
current_engagement_status = "ANALYZING..."
dominant_emotion = ""
is_analysis_running = False

# --- NEW: AI Analysis Function (for the worker thread) ---

def run_ai_analysis():
    """
    This function runs in a separate thread.
    It continuously analyzes the 'latest_frame'.
    """
    global current_engagement_status, dominant_emotion, latest_frame, is_analysis_running

    while True:
        # Check if there's a frame to analyze
        if latest_frame is None:
            time.sleep(0.1) # Wait for the main loop to provide a frame
            continue

        # Safely get a copy of the frame to analyze
        with data_lock:
            # We must make a copy, otherwise the main thread will
            # change the image while we're analyzing it!
            frame_to_analyze = latest_frame.copy()
        
        # --- OPTIMIZATION: Resize the frame ---
        # Analyzing a smaller image is MUCH faster.
        # We calculate a scaling factor to maintain aspect ratio
        target_width = 320 # Analyze at 320p width
        scale = target_width / frame_to_analyze.shape[1]
        dim = (target_width, int(frame_to_analyze.shape[0] * scale))
        
        try:
            # Resize the image for faster analysis
            resized_frame = cv2.resize(frame_to_analyze, dim, interpolation=cv2.INTER_AREA)

            # Let the main thread know we are busy
            is_analysis_running = True
            
            # --- Run the AI analysis ---
            analysis_results = DeepFace.analyze(
                resized_frame,
                actions=['emotion'],
                enforce_detection=True,
                detector_backend='retinaface' # Use 'retinaface' or 'mediapipe'
            )
            
            # Process results (DeepFace V1)
            if isinstance(analysis_results, list) and len(analysis_results) > 0:
                local_emotion = analysis_results[0]['dominant_emotion']
            # Process results (DeepFace V0)
            elif isinstance(analysis_results, dict):
                local_emotion = analysis_results['dominant_emotion']
            else:
                local_emotion = "unknown"

            local_status = EMOTIONS_TO_ENGAGEMENT.get(local_emotion, "UNKNOWN")

            # --- Safely update the global status ---
            with data_lock:
                dominant_emotion = local_emotion
                current_engagement_status = local_status
            
            is_analysis_running = False

        except Exception as e:
            # This happens if no face is found
            is_analysis_running = False
            with data_lock:
                dominant_emotion = ""
                current_engagement_status = "NO FACE DETECTED"
            # print(f"Analysis error: {e}") # Uncomment for debugging

        # Wait a little before the next analysis to not overload the CPU
        time.sleep(0.5) # Analyze ~2 times per second


# --- Initialization ---
cap = cv2.VideoCapture(VIDEO_SOURCE)
if not cap.isOpened():
    print(f"Error: Could not open video source '{VIDEO_SOURCE}'.")
    exit()

print("Starting video stream. Press 'q' to quit.")
print("Starting background AI analysis thread...")

# --- NEW: Start the worker thread ---
# daemon=True means this thread will automatically shut down
# when the main program (this script) exits.
ai_thread = threading.Thread(target=run_ai_analysis, daemon=True)
ai_thread.start()


# --- Main Video Loop (Runs on Main Thread) ---
while True:
    ret, frame = cap.read()
    if not ret:
        print("Error: Failed to grab frame. Stream ended?")
        break

    # --- NEW: Update the latest_frame for the AI thread ---
    with data_lock:
        latest_frame = frame.copy()
    
    display_frame = frame.copy()

    # --- Safely read the status from the worker thread ---
    with data_lock:
        status_to_display = current_engagement_status
        emotion_to_display = dominant_emotion
    
    # --- Display Status on Frame ---
    
    # Show a small "Analyzing..." text if the worker is busy
    if is_analysis_running:
        cv2.putText(display_frame, "Analyzing...", (10, 110),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2, cv2.LINE_AA)
    
    if status_to_display == "Engaged":
        status_color = (0, 255, 0)  # Green
    elif status_to_display == "Not Engaged":
        status_color = (0, 0, 255)  # Red
    else:
        status_color = (255, 255, 0) # Cyan

    # Display the main engagement status
    cv2.putText(display_frame, f"Status: {status_to_display}", (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX, 1, status_color, 2, cv2.LINE_AA)
    
    # Display the detected emotion
    cv2.putText(display_frame, f"Emotion: {emotion_to_display}", (10, 70),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2, cv2.LINE_AA)

    # --- Show the Window ---
    cv2.imshow("Student Engagement Monitor (Laptop/Server)", display_frame)

    # --- Quit Condition ---
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

# --- Cleanup ---
print("Shutting down...")
cap.release()
cv2.destroyAllWindows()