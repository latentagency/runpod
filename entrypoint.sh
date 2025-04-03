#!/bin/bash

# Define base directory dynamically
if [ -d "/runpod-volume/workspace" ]; then
    BASE_DIR="/runpod-volume/workspace"
else
    BASE_DIR="/workspace"
fi

# Log file for entrypoint debugging
LOG_FILE="${BASE_DIR}/comfyui/entrypoint.log"
echo "Entrypoint started at $(date)" >> "$LOG_FILE"

# Ensure handler.py and main.py are in BASE_DIR
cp /workspace/comfyui/handler.py "${BASE_DIR}/comfyui/handler.py" || { echo "Failed to copy handler.py" >> "$LOG_FILE"; exit 1; }
cp /workspace/comfyui/main.py "${BASE_DIR}/comfyui/main.py" || { echo "Failed to copy main.py" >> "$LOG_FILE"; exit 1; }

# Check for critical files to determine if installation is needed
SETUP_CHECK_MODEL="${BASE_DIR}/comfyui/models/unet/Flux/GGUF/flux1-dev-Q8_0.gguf"
SETUP_CHECK_NODE="${BASE_DIR}/comfyui/custom_nodes/ComfyUI-Manager"

# Debug file existence and permissions
echo "Checking model file: $SETUP_CHECK_MODEL" >> "$LOG_FILE"
echo "  Exists? $([ -f "$SETUP_CHECK_MODEL" ] && echo yes || echo no)" >> "$LOG_FILE"
echo "  Readable? $([ -r "$SETUP_CHECK_MODEL" ] && echo yes || echo no)" >> "$LOG_FILE"
echo "Checking node directory: $SETUP_CHECK_NODE" >> "$LOG_FILE"
echo "  Exists? $([ -d "$SETUP_CHECK_NODE" ] && echo yes || echo no)" >> "$LOG_FILE"
echo "  Readable? $([ -r "$SETUP_CHECK_NODE" ] && echo yes || echo no)" >> "$LOG_FILE"

if [ ! -f "$SETUP_CHECK_MODEL" ] || [ ! -d "$SETUP_CHECK_NODE" ] || [ ! -r "$SETUP_CHECK_MODEL" ] || [ ! -r "$SETUP_CHECK_NODE" ]; then
    echo "Critical files missing or inaccessible, running installation script at $(date)..." | tee -a "$LOG_FILE"
    ${BASE_DIR}/comfyui/install.sh || { echo "Installation script failed at $(date)" | tee -a "$LOG_FILE"; exit 1; }
else
    echo "Critical files found and accessible, skipping installation script at $(date)..." | tee -a "$LOG_FILE"
fi

# Get the mode from the first argument (e.g., "gui" or anything else for serverless)
MODE=$1
echo "Mode set to: $MODE at $(date)" >> "$LOG_FILE"

# Check mode and start appropriate process
if [ "$MODE" = "gui" ]; then
    echo "Starting ComfyUI in GUI mode on port 8188 at $(date)..." | tee -a "$LOG_FILE"
    exec python "${BASE_DIR}/comfyui/main.py" --listen 0.0.0.0 --port 8188
else
    echo "Starting in serverless mode at $(date)..." | tee -a "$LOG_FILE"
    exec python "${BASE_DIR}/comfyui/handler.py"
fi