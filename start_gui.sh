import os
import sys
import json
import comfy.options
from comfyui import server

# Define base directory (consistent with Dockerfile, install.sh, entrypoint.sh, and handler.py)
BASE_DIR="/workspace"

# Set the workflow to load (updated to use BASE_DIR)
WORKFLOW_PATH = f"{BASE_DIR}/comfyui/workflows/default_workflow.json"

# Load the workflow
with open(WORKFLOW_PATH, "r") as f:
    workflow = json.load(f)

# Simulate loading the workflow into the server
def main():
    # Parse command-line arguments for the server
    comfy.options.parse_args(["--listen", "0.0.0.0", "--port", "8188"])
    
    # Initialize and start the PromptServer
    prompt_server = server.PromptServer()
    prompt_server.start()
    
    # Here you’d typically send the workflow to the server, but this requires deeper integration
    # For simplicity, we’ll assume manual loading or API interaction for now
    prompt_server.loop.run_forever()

if __name__ == "__main__":
    main()