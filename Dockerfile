FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies as root.
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-venv \
    git \
    ffmpeg \
    build-essential \
    curl \
    awscli \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Set python/pip aliases (optional but helps for clean calls)
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Set the working directory.
WORKDIR /app

# --- CACHING OPTIMIZATION ---

# 1. Install pget utility first, as it's needed for weight downloads.
RUN curl -o /usr/local/bin/pget -L "https://github.com/replicate/pget/releases/latest/download/pget_$(uname -s)_$(uname -m)" && \
    chmod +x /usr/local/bin/pget

# 2. Copy ONLY the requirements file and the new download script.
COPY requirements.txt .
COPY scripts/download-weights.sh scripts/

# 3. Install CUDA-enabled torch/torchvision/torchaudio first!
RUN pip install --upgrade pip
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# 4. Now install all other Python dependencies (ComfyUI, etc)
RUN pip install --no-cache-dir -r requirements.txt

# 5. Run the weight download script. This creates a large, separate, cacheable layer.
RUN chmod +x scripts/download-weights.sh && ./scripts/download-weights.sh

# 6. Now copy the rest of your application code. Changes here won't trigger re-downloads.
COPY . .

# 7. Pre-install all custom nodes.
RUN python scripts/install_custom_nodes.py

# 8. Make the entrypoint script executable
RUN chmod +x scripts/run.sh

# 9. Install ComfyUI frontend pip requirements (if you want to always ensure frontend is up-to-date)
RUN pip install --no-cache-dir -r /app/ComfyUI/requirements.txt

# 10. Define the entrypoint for the container.
ENTRYPOINT ["./scripts/run.sh"]
