from transformers import BeitForImageClassification, AutoImageProcessor
from PIL import Image
import torch

# 1. Define the device to run on (GPU if available, otherwise CPU)
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Using device: {device}")

# 2. Load the pre-trained model and image processor
model_name = "nihar245/Expression-Detection-BEIT-Large"
model = BeitForImageClassification.from_pretrained(model_name).to(device)
processor = AutoImageProcessor.from_pretrained(model_name)

# 4. Prepare your image
try:
    image = Image.open("student_face.jpg").convert("RGB")
except FileNotFoundError:
    print("Error: 'student_face1.jpg' not found. Please add a test image.")
    exit()

# 5. Process the image and move it to the device
inputs = processor(images=image, return_tensors="pt").to(device)

with torch.no_grad():
    outputs = model(**inputs)
    probs = torch.nn.functional.softmax(outputs.logits, dim=-1)
    pred_class = torch.argmax(probs, dim=-1).item()

# Get prediction
labels = ["Bored", "Confused", "Engaged", "Neutral"]
print(f"Prediction: {labels[pred_class]} ({probs[0][pred_class]:.2%} confidence)")