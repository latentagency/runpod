import runpod
import os
import json
import subprocess
import base64
import shutil
from datetime import datetime

# Define base directory for data (consistent with install.sh and entrypoint.sh)
BASE_DIR = "/runpod-volume/workspace" if os.path.exists("/runpod-volume/workspace") else "/workspace"
OUTPUT_DIR = f"{BASE_DIR}/comfyui/output"
INPUT_DIR = f"{BASE_DIR}/comfyui/tmp/workflow_temp.json"

# Define directories (use BASE_DIR for data, /workspace for static files)
WORKFLOW_PATH = "/workspace/comfyui/workflow.json"
TEMP_WORKFLOW_PATH = f"{BASE_DIR}/comfyui/tmp/workflow_temp.json"
OUTPUT_DIR = f"{BASE_DIR}/comfyui/output"
TEMP_DIR = f"{BASE_DIR}/comfyui/tmp"
MAIN_PY_PATH = "/workspace/comfyui/main.py"
INPUT_DIR_PATH = f"{BASE_DIR}/comfyui/input"
EXAMPLES_DIR = "/workspace/comfyui/src/examples"

# Define the node IDs for relevant nodes with default paths
LOAD_IMAGE_NODES = {
    "1231": {"param": "subject_image", "default": os.path.join(EXAMPLES_DIR, "subject.png")},
    "1531": {"param": "background_image", "default": os.path.join(EXAMPLES_DIR, "background.png")}
}

SIMPLE_MATH_SLIDER_NODES = {
    "1088": {"name": "x_coordinate", "output_index": 0, "type": "FLOAT"},
    "1089": {"name": "y_coordinate", "output_index": 0, "type": "FLOAT"},
    "2151": {"name": "z_coordinate", "output_index": 0, "type": "FLOAT"},
    "2134": {"name": "variation_intensity", "output_index": 0, "type": "FLOAT"},
    "3914": {"name": "toggle_custom_prompt", "output_index": 1, "type": "INT"},
    "3920": {"name": "product_consistency", "output_index": 0, "type": "FLOAT"},
    "3921": {"name": "background_consistency", "output_index": 0, "type": "FLOAT"}
}

SEED_NODE = {
    "34": {"value_name": "seed", "mode_name": "seed_mode"}
}

VARIATION_COUNT_NODE = {
    "791": "variation_count"
}

VALID_SEED_MODES = {"fixed", "increment", "decrement", "randomize"}

def handler(event):
    # Version marker to confirm deployment
    print("Handler version: 2025-03-25-v1", flush=True)

    # Load the workflow
    print(f"Loading workflow from {WORKFLOW_PATH}", flush=True)
    try:
        with open(WORKFLOW_PATH, "r") as f:
            workflow = json.load(f)
    except Exception as e:
        print(f"Failed to load workflow: {str(e)}", flush=True)
        return {"status": "error", "message": f"Workflow load failed: {str(e)}"}

    # Extract input from the event
    input_data = event.get("input", {})
    print(f"Input data: {input_data}", flush=True)

    # Ensure directories exist
    os.makedirs(TEMP_DIR, exist_ok=True)
    os.makedirs(INPUT_DIR_PATH, exist_ok=True)
    print(f"Directories ensured: {TEMP_DIR}, {INPUT_DIR_PATH}", flush=True)

    # Update LoadImage nodes
    for node_id, info in LOAD_IMAGE_NODES.items():
        image_input = input_data.get(info["param"], info["default"])
        if image_input:
            for node in workflow["nodes"]:
                if str(node["id"]) == node_id:
                    if isinstance(image_input, str) and not image_input.startswith("data:image"):
                        filename = os.path.basename(image_input)
                        source_path = os.path.join(EXAMPLES_DIR, filename) if not os.path.isabs(image_input) else image_input
                        input_path = os.path.join(INPUT_DIR_PATH, filename)
                        print(f"Attempting to copy {source_path} to {input_path}", flush=True)
                        if os.path.exists(source_path):
                            shutil.copy(source_path, input_path)
                            print(f"Successfully copied {source_path} to {input_path}", flush=True)
                        else:
                            print(f"Warning: Input file {source_path} not found, using default.", flush=True)
                            shutil.copy(info["default"], input_path)
                            print(f"Copied default {info['default']} to {input_path}", flush=True)
                        node["widgets_values"][0] = filename
                    elif isinstance(image_input, str) and image_input.startswith("data:image"):
                        base64_data = image_input.split(",")[1]
                        temp_filename = f"{info['param']}_{node_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
                        temp_path = os.path.join(TEMP_DIR, temp_filename)
                        with open(temp_path, "wb") as f:
                            f.write(base64.b64decode(base64_data))
                        input_path = os.path.join(INPUT_DIR_PATH, temp_filename)
                        shutil.copy(temp_path, input_path)
                        print(f"Copied base64 image to {input_path}", flush=True)
                        node["widgets_values"][0] = temp_filename
                    break

    # Update SimpleMathSlider+ nodes
    for node_id, info in SIMPLE_MATH_SLIDER_NODES.items():
        value = input_data.get(info["name"])
        if value is not None:
            for node in workflow["nodes"]:
                if str(node["id"]) == node_id:
                    node["widgets_values"][0] = float(value) if info["type"] == "FLOAT" else int(value)
                    print(f"Updated node {node_id} with value {value}", flush=True)
                    break

    # Update Seed node (value and mode)
    for node_id, params in SEED_NODE.items():
        seed_value = input_data.get(params["value_name"])
        seed_mode = input_data.get(params["mode_name"])
        for node in workflow["nodes"]:
            if str(node["id"]) == node_id:
                if seed_value is not None:
                    node["widgets_values"][0] = int(seed_value)
                    print(f"Updated seed value for node {node_id} to {seed_value}", flush=True)
                if seed_mode in VALID_SEED_MODES:
                    node["widgets_values"][1] = seed_mode
                    print(f"Updated seed mode for node {node_id} to {seed_mode}", flush=True)
                break

    # Update Variation Count node
    for node_id, param_name in VARIATION_COUNT_NODE.items():
        value = input_data.get(param_name)
        if value is not None:
            for node in workflow["nodes"]:
                if str(node["id"]) == node_id:
                    node["widgets_values"][0] = int(value)
                    print(f"Updated variation count for node {node_id} to {value}", flush=True)
                    break

    # Save the modified workflow to a temporary file
    os.makedirs(os.path.dirname(TEMP_WORKFLOW_PATH), exist_ok=True)
    with open(TEMP_WORKFLOW_PATH, "w") as f:
        json.dump(workflow, f)
    print(f"Saved temp workflow to {TEMP_WORKFLOW_PATH}", flush=True)

    # Clear previous output directory
    if os.path.exists(OUTPUT_DIR):
        shutil.rmtree(OUTPUT_DIR)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Cleared and recreated output directory: {OUTPUT_DIR}", flush=True)

    # Run ComfyUI with the workflow
    print("Running ComfyUI...", flush=True)
    try:
        result = subprocess.run([
            "python", MAIN_PY_PATH,
            "--input", TEMP_WORKFLOW_PATH,
            "--output-directory", OUTPUT_DIR,
            "--force-fp16"
        ], check=True, capture_output=True, text=True)
        print(f"main.py stdout: {result.stdout}", flush=True)
        print(f"main.py stderr: {result.stderr}", flush=True)
    except subprocess.CalledProcessError as e:
        print(f"main.py failed with exit code {e.returncode}", flush=True)
        print(f"stdout: {e.stdout}", flush=True)
        print(f"stderr: {e.stderr}", flush=True)
        return {"status": "error", "message": f"ComfyUI execution failed: {e.stderr}"}

    # Collect output images
    output_images = []
    for filename in os.listdir(OUTPUT_DIR):
        if filename.endswith((".png", ".jpg", ".jpeg")):
            output_images.append(os.path.join(OUTPUT_DIR, filename))
    print(f"Output images: {output_images}", flush=True)

    # Prepare response
    if not output_images:
        return {"status": "error", "message": "No images generated"}

    return {
        "status": "success",
        "output": [
            {"file": path, "type": "image/png"} for path in output_images
        ]
    }

# Start the RunPod serverless worker
runpod.serverless.start({"handler": handler})