import runpod
import os
import json
import subprocess
import shutil

# Define base directory for data (consistent with install.sh and entrypoint.sh)
BASE_DIR = "/runpod-volume/workspace" if os.path.exists("/runpod-volume/workspace") else "/workspace"
OUTPUT_DIR = f"{BASE_DIR}/comfyui/output"
TEMP_WORKFLOW_PATH = f"{BASE_DIR}/comfyui/tmp/workflow_temp.json"

# Define directories
WORKFLOW_PATH = "/workspace/comfyui/workflow.json"
MAIN_PY_PATH = "/workspace/comfyui/main.py"
TEMP_DIR = f"{BASE_DIR}/comfyui/tmp"

# Define node IDs and their parameters from the workflow
CLIP_TEXT_NODES = {
    "6": {"param": "positive_prompt", "default": "beautiful scenery nature glass bottle landscape, , purple galaxy bottle,"},
    "7": {"param": "negative_prompt", "default": "text, watermark"}
}

KSAMPLER_NODE = {
    "3": {
        "seed": "seed",
        "steps": "steps",
        "cfg": "cfg",
        "sampler_name": "sampler_name",
        "scheduler": "scheduler",
        "denoise": "denoise"
    }
}

LATENT_IMAGE_NODE = {
    "5": {
        "width": "width",
        "height": "height",
        "batch_size": "batch_size"
    }
}

VALID_SAMPLER_NAMES = {"euler", "euler_ancestral", "heun", "dpm_2", "dpm_fast", "dpm_adaptive", "dpmpp_2m", "dpmpp_sde"}
VALID_SCHEDULERS = {"normal", "karras", "exponential", "simple"}

def handler(event):
    # Version marker to confirm deployment
    print("Handler version: 2025-04-03-v1", flush=True)

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

    # Ensure temp directory exists
    os.makedirs(TEMP_DIR, exist_ok=True)
    print(f"Temp directory ensured: {TEMP_DIR}", flush=True)

    # Update CLIPTextEncode nodes (positive and negative prompts)
    for node_id, info in CLIP_TEXT_NODES.items():
        prompt_input = input_data.get(info["param"], info["default"])
        for node in workflow["nodes"]:
            if str(node["id"]) == node_id:
                node["widgets_values"][0] = prompt_input
                print(f"Updated node {node_id} with prompt: {prompt_input}", flush=True)
                break

    # Update KSampler node (seed, steps, cfg, etc.)
    for node_id, params in KSAMPLER_NODE.items():
        for node in workflow["nodes"]:
            if str(node["id"]) == node_id:
                seed = input_data.get(params["seed"])
                if seed is not None:
                    node["widgets_values"][0] = int(seed)
                    print(f"Updated seed for node {node_id} to {seed}", flush=True)
                
                steps = input_data.get(params["steps"])
                if steps is not None:
                    node["widgets_values"][2] = int(steps)
                    print(f"Updated steps for node {node_id} to {steps}", flush=True)
                
                cfg = input_data.get(params["cfg"])
                if cfg is not None:
                    node["widgets_values"][3] = float(cfg)
                    print(f"Updated cfg for node {node_id} to {cfg}", flush=True)
                
                sampler_name = input_data.get(params["sampler_name"])
                if sampler_name in VALID_SAMPLER_NAMES:
                    node["widgets_values"][4] = sampler_name
                    print(f"Updated sampler_name for node {node_id} to {sampler_name}", flush=True)
                
                scheduler = input_data.get(params["scheduler"])
                if scheduler in VALID_SCHEDULERS:
                    node["widgets_values"][5] = scheduler
                    print(f"Updated scheduler for node {node_id} to {scheduler}", flush=True)
                
                denoise = input_data.get(params["denoise"])
                if denoise is not None:
                    node["widgets_values"][6] = float(denoise)
                    print(f"Updated denoise for node {node_id} to {denoise}", flush=True)
                break

    # Update EmptyLatentImage node (width, height, batch_size)
    for node_id, params in LATENT_IMAGE_NODE.items():
        for node in workflow["nodes"]:
            if str(node["id"]) == node_id:
                width = input_data.get(params["width"])
                if width is not None:
                    node["widgets_values"][0] = int(width)
                    print(f"Updated width for node {node_id} to {width}", flush=True)
                
                height = input_data.get(params["height"])
                if height is not None:
                    node["widgets_values"][1] = int(height)
                    print(f"Updated height for node {node_id} to {height}", flush=True)
                
                batch_size = input_data.get(params["batch_size"])
                if batch_size is not None:
                    node["widgets_values"][2] = int(batch_size)
                    print(f"Updated batch_size for node {node_id} to {batch_size}", flush=True)
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