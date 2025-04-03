#!/bin/bash

# Define base directory dynamically (prefer volume if available)
if [ -d "/runpod-volume/workspace" ]; then
    BASE_DIR="/runpod-volume/workspace"
else
    BASE_DIR="/workspace"
fi

# Log output to a file for debugging (using BASE_DIR)
LOG_FILE="${BASE_DIR}/comfyui/setup.log"
echo "Logging setup process to $LOG_FILE at $(date)"
exec > >(tee -a "$LOG_FILE") 2>&1

# Define directories (using BASE_DIR)
CUSTOM_NODES_DIR="${BASE_DIR}/comfyui/custom_nodes"
MODELS_DIR="${BASE_DIR}/comfyui/models"
UNET_DIR="${MODELS_DIR}/unet/Flux/GGUF"
LORAS_DIR="${MODELS_DIR}/loras"
VAE_DIR="${MODELS_DIR}/vae"
CLIP_DIR="${MODELS_DIR}/clip/clip"
T5_DIR="${MODELS_DIR}/clip/t5"
STYLE_DIR="${MODELS_DIR}/style_models"
CLIP_VISION_DIR="${MODELS_DIR}/clip_vision"
CONTROLNET_DIR="${MODELS_DIR}/controlnet/FLUX"
LLM_DIR="${MODELS_DIR}/LLM"

# Early exit if environment is already set up
if [ -f "$UNET_DIR/flux1-dev-Q8_0.gguf" ] && [ -d "$CUSTOM_NODES_DIR/ComfyUI-Manager" ]; then
    echo "Environment already set up, skipping installation at $(date)..."
    exit 0
fi

# Create directories if they don’t exist
mkdir -p "$CUSTOM_NODES_DIR" "$UNET_DIR" "$LORAS_DIR" "$VAE_DIR" "$CLIP_DIR" "$T5_DIR" "$STYLE_DIR" "$CLIP_VISION_DIR" "$CONTROLNET_DIR" "$LLM_DIR"

# Function to clone a repository and checkout a specific commit
clone_repo() {
    local repo_url=$1
    local commit_hash=$2
    local folder_name=$(basename "$repo_url" .git)
    local target_dir="$CUSTOM_NODES_DIR/$folder_name"

    # Allow overriding target_dir if provided as third argument
    if [ -n "$3" ]; then
        target_dir="$3"
    fi

    if [ ! -d "$target_dir" ]; then
        echo "Cloning $repo_url into $target_dir..."
        if ! git clone "$repo_url" "$target_dir" 2>/dev/null; then
            echo "Failed to clone $repo_url. Retrying once..."
            sleep 2
            if ! git clone "$repo_url" "$target_dir"; then
                echo "Failed to clone $repo_url after retry, skipping..."
                return 1
            fi
        fi
        cd "$target_dir" || { echo "Failed to enter $target_dir"; return 1; }
        if [ -n "$commit_hash" ]; then
            echo "Checking out commit $commit_hash for $folder_name..."
            if ! git checkout "$commit_hash" 2>/dev/null; then
                echo "Failed to checkout commit $commit_hash"
            fi
        fi
        cd - >/dev/null || { echo "Failed to return to previous directory"; return 1; }
    else
        echo "$folder_name already exists at $target_dir, skipping clone..."
    fi

    if [ -f "$target_dir/requirements.txt" ]; then
        echo "Installing requirements for $folder_name..."
        pip3 install -r "$target_dir/requirements.txt" --no-cache-dir || echo "Failed to install requirements for $folder_name"
    fi
}

# List of custom nodes with specific commits (prioritize ComfyUI-Manager)
clone_repo "https://github.com/ltdrdata/ComfyUI-Manager.git" "a52b4eb5eda2a098b4ee597c361a8c4de56bf9a3"
clone_repo "https://github.com/BlenderNeko/ComfyUI_Noise.git" "0c9ec19b16dc72334cb8ce82c3774aed183048e4"
clone_repo "https://github.com/farizrifqi/ComfyUI-Image-Saver.git" "65e6903eff274a50f8b5cd768f0f96baf37baea1"
clone_repo "https://github.com/jamesWalker55/comfyui-various.git" "36454f91606bbff4fc36d90234981ca4a47e2695"
clone_repo "https://github.com/Stability-AI/stability-ComfyUI-nodes.git" "001154622564b17223ce0191803c5fff7b87146c"
clone_repo "https://github.com/WASasquatch/was-node-suite-comfyui.git" "056badacda52e88d29d6a65f9509cd3115ace0f2"
clone_repo "https://github.com/M1kep/ComfyLiterals.git" "bdddb08ca82d90d75d97b1d437a652e0284a32ac"
clone_repo "https://github.com/spacepxl/ComfyUI-Image-Filters.git" "0ff33fe29f7be072ad5d2cd89efa18fed82957fe"
clone_repo "https://github.com/rgthree/rgthree-comfy.git" "5d771b8b56a343c24a26e8cea1f0c87c3d58102f"
clone_repo "https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git" "4991451b73c7f7030114ecce67f31d75aee8a155"
clone_repo "https://github.com/chrisgoringe/cg-use-everywhere.git" "ce510b97d10e69d5fd0042e115ecd946890d2079"
clone_repo "https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git" "0e2a9aca02b17dde91577bfe4b65861df622dcaf"
clone_repo "https://github.com/erosDiffusion/ComfyUI-enricos-nodes.git" "c4922285ebf0ac494e188bfcd7ca9fb3b88471d7"
clone_repo "https://github.com/Fannovel16/comfyui_controlnet_aux.git" "5a049bde9cc117dafc327cded156459289097ea1"
clone_repo "https://github.com/city96/ComfyUI-GGUF.git" "5875c52f59baca3a9372d68c43a3775e21846fe0"
clone_repo "https://github.com/ShmuelRonen/ComfyUI-Apply_Style_Model_Adjust.git" "45b561612588ceefb0938d163b106057bb44e516"
clone_repo "https://github.com/kadirnar/ComfyUI-YOLO.git" "8c7d8fd0e5eaa5569f04be1e8f4219801d682624"
clone_repo "https://github.com/cubiq/ComfyUI_essentials.git" "33ff89fd354d8ec3ab6affb605a79a931b445d99"
clone_repo "https://github.com/kijai/comfyui-kjnodes.git" "1a4259f05206d7360be7a90145b5839d5b64d893"
clone_repo "https://github.com/yolain/ComfyUI-Easy-Use.git" "0daf114fe8870aeacfea484aa59e7f9973b91cd5"
clone_repo "https://github.com/gseth/ControlAltAI-Nodes.git" "404b22d09283b2ece48da6c4e024d4d6beaecb07"
clone_repo "https://github.com/vault-developer/comfyui-image-blender.git" "21fc6d828ea19b9bf7b11fb8c57c647be555e5b8"
clone_repo "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" "bbda5e52ad580c13ceaa53136d9c2bed9137bd2e"
clone_repo "https://github.com/kijai/comfyui-ic-light.git" "0208191a9bd2a214167c8a52237ecadd1fa0220c"
clone_repo "https://github.com/kijai/ComfyUI-Florence2.git" "90b012e922f8bb0482bcd2ae24cdc191ec12a11f"
clone_repo "https://github.com/lum3on/comfyui_LLM_Polymath.git" "9bd1df67d4acaa0124889d3a171125d6423f5695"
clone_repo "https://github.com/kijai/comfyui-fluxtrainer.git" "639b3e80ba66e42605a34f393b576cd489e06734"
clone_repo "https://github.com/ZHO-ZHO-ZHO/ComfyUI-YoloWorld-EfficientSAM.git" "dcb7865308f95734972e27d220d6d71b619991ac"
clone_repo "https://github.com/un-seen/comfyui-tensorops.git" "d34488e3079ecd10db2fe867c3a7af568115faed"
clone_repo "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "808b0dedf03534a2594ecb60a9d6305a044efdc2"
clone_repo "https://github.com/chflame163/ComfyUI_LayerStyle.git" "7b326d13e43fc4022cd80e472c7af67027409b1e"
clone_repo "https://github.com/Jonseed/ComfyUI-Detail-Daemon.git" "90e703d3d3f979438471c646a5d030840a2caac3"
clone_repo "https://github.com/crystian/ComfyUI-Crystools.git" "72e2e9af4a6b9a58ca5d753cacff37ba1ff9bfa8"
clone_repo "https://github.com/john-mnz/ComfyUI-Inspyrenet-Rembg.git" "87ac452ef1182e8f35f59b04010158d74dcefd06"
clone_repo "https://github.com/heshengtao/comfyui_llm_party.git" "7d7e246bd0c7b31864ece5d7a5e76eecbdf93787"

# Clone Florence-2-large-PromptGen-v2.0 into models/LLM
clone_repo "https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0" "" "${LLM_DIR}/Florence-2-large-PromptGen-v2.0"

# Function to download files using wget
download_model() {
    local url=$1
    local output_path=$2
    if [ ! -f "$output_path" ]; then
        echo "Downloading model from $url to $output_path..."
        if ! wget -O "$output_path" "$url" 2>/dev/null; then
            echo "Failed to download $url, retrying once after 2 seconds..."
            sleep 2
            if wget -O "$output_path" "$url" 2>/dev/null; then
                echo "Successfully downloaded $output_path"
            else
                echo "Failed to download $url after retry"
            fi
        else
            echo "Successfully downloaded $output_path"
        fi
    else
        echo "$output_path already exists, skipping..."
    fi
}

# Download models with wget
download_model "https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q8_0.gguf?download=true" "$UNET_DIR/flux1-dev-Q8_0.gguf"
download_model "https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q8_0.gguf?download=true" "$T5_DIR/t5-v1_1-xxl-encoder-Q8_0.gguf"
download_model "https://huggingface.co/zer0int/CLIP-GmP-ViT-L-14/resolve/main/ViT-L-14-BEST-smooth-GmP-ft.safetensors" "$CLIP_DIR/ViT-L-14-BEST-smooth-GmP-ft.safetensors"
download_model "https://huggingface.co/Runware/FLUX.1-Redux-dev/resolve/main/flux1-redux-dev.safetensors?download=true" "$STYLE_DIR/flux1-redux-dev.safetensors"
download_model "https://huggingface.co/ByteDance/Hyper-SD/resolve/main/Hyper-FLUX.1-dev-8steps-lora.safetensors" "$LORAS_DIR/Hyper-flux1-dev-8steps-lora.safetensors"
download_model "https://huggingface.co/lovis93/testllm/resolve/ed9cf1af7465cebca4649157f118e331cf2a084f/ae.safetensors?download=true" "$VAE_DIR/ae.safetensors"
download_model "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/diffusion_pytorch_model.safetensors?download=true" "$VAE_DIR/sdxl_vae.safetensors"
download_model "https://huggingface.co/Comfy-Org/sigclip_vision_384/resolve/main/sigclip_vision_patch14_384.safetensors?download=true" "$CLIP_VISION_DIR/sigclip_vision_patch14_384.safetensors"
download_model "https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro/resolve/main/diffusion_pytorch_model.safetensors?download=true" "$CONTROLNET_DIR/flux1-dev-ControlNet-Union-Pro.safetensors"

echo "Installation complete at $(date)!"