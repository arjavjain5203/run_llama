# run_ollama.py
import os
import subprocess
import sys
import psutil
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

# ==========================
# Configuration
# ==========================
OLLAMA_CLI_PATH = "ollama"  # assume it's on PATH, or specify full path
MODEL_8GB = "llama-3.1-8b-q"
MODEL_16GB = "gpt-oss-20b-g"
APP_PORT = 11434

# ==========================
# Helper functions
# ==========================
def install_ollama():
    """Install Ollama CLI if not found"""
    print("[*] Checking Ollama CLI...")
    try:
        subprocess.run([OLLAMA_CLI_PATH, "--version"], check=True, stdout=subprocess.PIPE)
        print("[*] Ollama CLI already installed")
    except Exception:
        print("[!] Ollama not found, installing...")
        # Assuming Ollama can be installed via pip
        subprocess.run([sys.executable, "-m", "pip", "install", "ollama"], check=True)
        print("[+] Ollama installed successfully")

def select_model():
    """Select model based on system RAM"""
    ram_gb = psutil.virtual_memory().total / (1024 ** 3)
    print(f"[*] Detected RAM: {ram_gb:.1f} GB")
    if ram_gb <= 8:
        return MODEL_8GB
    elif ram_gb >= 16:
        return MODEL_16GB
    else:
        print("[!] RAM in between 8-16GB, defaulting to 8B model")
        return MODEL_8GB

def download_model(model_name):
    """Download the model if not present"""
    print(f"[*] Checking if model {model_name} is installed...")
    try:
        result = subprocess.run([OLLAMA_CLI_PATH, "list"], capture_output=True, text=True)
        if model_name in result.stdout:
            print(f"[*] Model {model_name} already installed")
            return
    except Exception as e:
        print(f"[!] Error checking models: {e}")

    print(f"[+] Downloading model {model_name}...")
    subprocess.run([OLLAMA_CLI_PATH, "pull", model_name], check=True)
    print(f"[+] Model {model_name} downloaded successfully")

# ==========================
# FastAPI LLM wrapper
# ==========================
app = FastAPI(title="Ollama LLM API")

class Query(BaseModel):
    prompt: str
    max_tokens: int = 256

@app.post("/v1/query")
def query_llm(q: Query):
    """Send prompt to Ollama CLI and return response"""
    try:
        result = subprocess.run(
            [OLLAMA_CLI_PATH, "run", model, "--prompt", q.prompt, "--max-tokens", str(q.max_tokens)],
            capture_output=True, text=True, check=True
        )
        return {"output": result.stdout.strip()}
    except Exception as e:
        return {"error": str(e)}

# ==========================
# Main execution
# ==========================
if __name__ == "__main__":
    # Step 1: Install Ollama if needed
    install_ollama()

    # Step 2: Select model based on hardware
    model = select_model()

    # Step 3: Download model if missing
    download_model(model)

    # Step 4: Start FastAPI server
    print(f"[*] Starting FastAPI LLM server on port {APP_PORT} with model {model}")
    uvicorn.run(app, host="0.0.0.0", port=APP_PORT)
