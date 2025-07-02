#!/bin/bash
set -e

echo "--- Pre-warming model caches ---"

# Create target directories
mkdir -p /app/ComfyUI/models/BiRefNet
mkdir -p /root/.cache/torch/hub/checkpoints/
mkdir -p /app/ComfyUI/models/LLM
mkdir -p /app/ComfyUI/models/RMBG/RMBG-2.0

# Download SAM2 Hiera Base Plus Model
echo "Downloading sam2_hiera_base_plus.safetensors..."
mkdir -p /app/ComfyUI/models/sam2
pget -xf "https://weights.replicate.delivery/default/comfy-ui/sam2/sam2_hiera_base_plus.safetensors.tar" /app/ComfyUI/models/sam2/

# Download SDXL-Flash Model
echo "Downloading SDXL-Flash.safetensors..."
pget -xf "https://weights.replicate.delivery/default/comfy-ui/checkpoints/SDXL-Flash.safetensors.tar" /app/ComfyUI/models/checkpoints/

# Download BiRefNet Models
echo "Downloading BiRefNet models..."
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/swin_large_patch4_window12_384_22kto1k.pth.tar" /app/ComfyUI/models/BiRefNet/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/pvt_v2_b2.pth.tar" /app/ComfyUI/models/BiRefNet/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/BiRefNet-ep480.pth.tar" /app/ComfyUI/models/BiRefNet/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/BiRefNet-DIS_ep580.pth.tar" /app/ComfyUI/models/BiRefNet/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/swin_base_patch4_window12_384_22kto1k.pth.tar" /app/ComfyUI/models/BiRefNet/
pget -xf "https://weights.replicate.delivery/default/comfy-ui/BiRefNet/pvt_v2_b5.pth.tar" /app/ComfyUI/models/BiRefNet/

# Download ControlNet Aux Model
echo "Downloading ControlNet Aux models..."
pget -xf "https://weights.replicate.delivery/default/comfy-ui/custom_nodes/comfyui_controlnet_aux/mobilenet_v2-b0353104.pth.tar" /root/.cache/torch/hub/checkpoints/

# Download Florence-2-base (LLM) Model
echo "Downloading Florence2-base model..."
mkdir -p /app/ComfyUI/models/LLM/Florence-2-base
pget -xf "https://weights.replicate.delivery/default/comfy-ui/LLM/Florence-2-base.tar" /app/ComfyUI/models/LLM/

# Download RMBG-2.0 Model
echo "Downloading RMBG-2.0 model..."
mkdir -p /app/ComfyUI/models/RMBG/RMBG-2.0/
aws s3 cp s3://lbbw-trikot/workflow-assets/model.safetensors /app/ComfyUI/models/RMBG/RMBG-2.0/model.safetensors

echo "--- Finished pre-warming caches ---"
