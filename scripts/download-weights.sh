#!/bin/bash
set -e

echo "--- Pre-warming model caches ---"

# Download SAM2 Hiera Base Plus Model
echo "Downloading sam2_hiera_base_plus.safetensors..."
mkdir -p /app/ComfyUI/models/sam2
pget -xf "https://weights.replicate.delivery/default/comfy-ui/sam2/sam2_hiera_base_plus.safetensors.tar" /app/ComfyUI/models/sam2/

# Download crest.safetensors
# echo "Downloading crest.safetensors..."
mkdir -p /app/ComfyUI/models/loras
aws s3 cp s3://lbbw-trikot/workflow-assets/crest.safetensors /app/ComfyUI/models/loras/crest.safetensors

# Download clip_1.safetensors
echo "Downloading clip_1.safetensors..."
mkdir -p /app/ComfyUI/models/text_encoders
pget https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors /app/ComfyUI/models/text_encoders/clip_l.safetensors

# Download vae.safetensors
echo "Downloading vae.safetensors..."
mkdir -p /app/ComfyUI/models/vae
pget https://huggingface.co/lovis93/testllm/resolve/ed9cf1af7465cebca4649157f118e331cf2a084f/ae.safetensors /app/ComfyUI/models/text_encoders/ae.safetensors

# Download inswapper_128.safetensors
echo "Downloading inswapper_128.safetensors..."
mkdir -p /app/ComfyUI/models/insightface
pget https://huggingface.co/ezioruan/inswapper_128.onnx/resolve/main/inswapper_128.onnx /app/ComfyUI/models/text_encoders/inswapper_128.onnx


# Download BiRefNet Models
echo "Downloading BiRefNet models..."
mkdir -p /app/ComfyUI/models/BiRefNet
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/swin_large_patch4_window12_384_22kto1k.pth.tar" /app/ComfyUI/models/BiRefNet/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/pvt_v2_b2.pth.tar" /app/ComfyUI/models/BiRefNet/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/BiRefNet-ep480.pth.tar" /app/ComfyUI/models/BiRefNet/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/BiRefNet-DIS_ep580.pth.tar" /app/ComfyUI/models/BiRefNet/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/swin_base_patch4_window12_384_22kto1k.pth.tar" /app/ComfyUI/models/BiRefNet/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/pvt_v2_b5.pth.tar" /app/ComfyUI/models/BiRefNet/

# Download ControlNet Aux Model
echo "Downloading ControlNet Aux models..."
mkdir -p /root/.cache/torch/hub/checkpoints/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/custom_nodes/comfyui_controlnet_aux/mobilenet_v2-b0353104.pth.tar" /root/.cache/torch/hub/checkpoints/

# Download Florence-2-base (LLM) Model
echo "Downloading Florence2-base model..."
mkdir -p /app/ComfyUI/models/LLM/Florence-2-base
pget -xf "https://weights.replicate.delivery/default/comfy-ui/LLM/Florence-2-base.tar" /app/ComfyUI/models/LLM/

# Download ComfyUI Models and Files
echo "Downloading RMBG-2.0 model..."
mkdir -p /app/ComfyUI/models/RMBG/RMBG-2.0/
aws s3 cp s3://lbbw-trikot/workflow-assets/model.safetensors /app/ComfyUI/models/RMBG/RMBG-2.0/model.safetensors

mkdir -p /app/ComfyUI/models/ultralytics/bbox/
aws s3 cp s3://lbbw-trikot/workflow-assets/face_yolov8m.pt /app/ComfyUI/models/ultralytics/bbox/face_yolov8m.pt

mkdir -p /app/ComfyUI/models/sams/
aws s3 cp s3://lbbw-trikot/workflow-assets/sam_vit_l_0b3195.pth /app/ComfyUI/models/sams/sam_vit_l_0b3195.pth

echo "--- Finished pre-warming caches ---"
