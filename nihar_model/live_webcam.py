from transformers import BeitForImageClassification, AutoImageProcessor
from facenet_pytorch import MTCNN
from PIL import Image
import torch
import cv2

# 1. Define the device to run on (GPU if available, otherwise CPU)
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Using device: {device}")

# 2. Load the pre-trained model and image processor
model_name = "nihar245/Expression-Detection-BEIT-Large"
model = BeitForImageClassification.from_pretrained(model_name).to(device)
processor = AutoImageProcessor.from_pretrained(model_name)

# --- FIX 1: Use the dynamically determined 'device' for MTCNN ---
mtcnn = MTCNN(keep_all=True, device=device) 

labels = ["Bored", "Confused", "Engaged", "Neutral"]

cap = cv2.VideoCapture(0)

while True:
    ret, frame = cap.read()
    if not ret:
        break
    
    # Detect faces. MTCNN expects RGB input, so convert the frame
    # Note: MTCNN in facenet-pytorch is optimized for performance, 
    # and handles device movement internally based on the 'device' argument.
    boxes, _ = mtcnn.detect(frame)
    
    if boxes is not None:
        for box in boxes:
            x1, y1, x2, y2 = [int(b) for b in box]
            
            # Ensure coordinates are valid for cropping
            x1, y1, x2, y2 = max(0, x1), max(0, y1), min(frame.shape[1], x2), min(frame.shape[0], y2)
            face = frame[y1:y2, x1:x2]
            
            # --- FIX 2: Ensure face is not empty before processing (Avoids cv2.error: -215) ---
            if face.size == 0:
                continue

            # Predict engagement
            face_pil = Image.fromarray(cv2.cvtColor(face, cv2.COLOR_BGR2RGB))
            inputs = processor(images=face_pil, return_tensors="pt")
            
            # --- FIX 3: Move ALL input tensors to the correct device (Resolves RuntimeError) ---
            inputs = {k: v.to(device) for k, v in inputs.items()}
            
            with torch.no_grad():
                outputs = model(**inputs)
                
                # Get prediction using the fixed method from earlier conversations
                probs = torch.nn.functional.softmax(outputs.logits, dim=-1)
                pred_class_idx = torch.argmax(probs, dim=-1).item()
                
                # Optional: Get confidence score
                confidence = probs[0, pred_class_idx].item()
                
            prediction_label = f"{labels[pred_class_idx]} ({confidence:.2%})"

            # Draw results
            color = (0, 255, 0) if labels[pred_class_idx] == "Engaged" else (0, 165, 255)
            cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
            cv2.putText(frame, prediction_label, (x1, y1-10), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
    
    cv2.imshow('Engagement Detection', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()