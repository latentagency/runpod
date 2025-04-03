# Use an NVIDIA CUDA 12.4 base image with development tools
FROM nvidia/cuda:12.4.0-devel-ubuntu22.04

# Define base directory variable (default to /workspace for RunPod network volume)
ARG BASE_DIR=/workspace
WORKDIR ${BASE_DIR}/comfyui

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHON_VERSION=3.10.11

# Install system dependencies, OpenGL libraries, and Python 3.10
RUN apt-get update && apt-get install -y \
    software-properties-common \
    libgl1-mesa-glx \
    libglib2.0-0 \
    python3.10 \
    python3.10-dev \
    python3.10-distutils \
    git \
    wget \
    curl \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10 \
    && ln -sf /usr/local/bin/pip3.10 /usr/bin/pip3 \
    && python3 --version \
    && pip3 --version \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install PyTorch with CUDA 12.4 support
RUN pip3 install --no-cache-dir --upgrade pip
RUN pip3 install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124

# Clone ComfyUI with the specific commit
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . && \
    git checkout 96d891cb94d90f220e066cebad349887137f07a6

# Install Python dependencies for ComfyUI and huggingface_hub
RUN pip3 install --no-cache-dir -r requirements.txt || { echo "Failed to install ComfyUI requirements"; exit 1; }
RUN pip3 install --no-cache-dir huggingface_hub

# Install RunPod SDK for serverless worker
RUN pip3 install runpod

# Create directories for models and input/output (using BASE_DIR)
RUN mkdir -p ${BASE_DIR}/comfyui/input ${BASE_DIR}/comfyui/output

# Copy the installation script, workflow, and handler script (using BASE_DIR)
COPY install.sh ${BASE_DIR}/comfyui/install.sh
COPY entrypoint.sh ${BASE_DIR}/comfyui/entrypoint.sh
COPY workflow.json ${BASE_DIR}/comfyui/workflow.json
COPY handler.py ${BASE_DIR}/comfyui/handler.py
COPY test_input.json ${BASE_DIR}/comfyui/test_input.json
COPY /src/examples/background.png ${BASE_DIR}/comfyui/src/examples/background.png
COPY /src/examples/subject.png ${BASE_DIR}/comfyui/src/examples/subject.png

# Make the scripts executable
RUN chmod +x ${BASE_DIR}/comfyui/install.sh ${BASE_DIR}/comfyui/entrypoint.sh

# Copy workflow to a default location for GUI auto-loading (using BASE_DIR)
RUN mkdir -p ${BASE_DIR}/comfyui/workflows && \
    cp ${BASE_DIR}/comfyui/workflow.json ${BASE_DIR}/comfyui/workflows/default_workflow.json

# Expose ports for GUI (8188) and serverless (80)
EXPOSE 8188
EXPOSE 80

# Use entrypoint script from the image (not the volume)
ENTRYPOINT ["/workspace/comfyui/entrypoint.sh"]

# Default to serverless mode
CMD ["serverless"]