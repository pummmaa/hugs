---
title: "running-ai-models-on-docker"
date: 2026-08-21T01:29:24Z
lastmod: 2026-08-21T01:29:24Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Running AI Models with Docker — Complete Guide

A practical, end-to-end guide to running AI models locally in Docker containers,
covering `docker run` commands and `docker compose` stacks for the most common
serving tools (Ollama, Hugging Face TGI, vLLM, and custom models).

---

## Table of Contents

1. Prerequisites
2. Option A — Ollama (Easiest)
3. Option B — Hugging Face TGI
4. Option C — vLLM (OpenAI-compatible)
5. Option D — Custom Model Container
6. Docker Compose Setups
7. Managing a Compose Stack
8. Best Practices & Gotchas
9. Which Should You Pick?

---

## 1. Prerequisites

**Install Docker**

- Linux: install Docker Engine
- macOS / Windows: install Docker Desktop

Verify:

```bash
docker --version
docker run hello-world
```

**For GPU acceleration (NVIDIA)** — install the NVIDIA Container Toolkit:

```bash
# Ubuntu example
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Test GPU access inside a container:

```bash
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
```

> On CPU-only machines, drop `--gpus all` — tools still run, just slower.
> Apple Silicon (M-series) has no Docker GPU passthrough; run those tools natively for GPU speed.
> 

---

## 2. Option A — Ollama (Easiest)

The simplest way to run open models (Llama, Mistral, Gemma, Qwen, etc.).

**Start the server:**

```bash
docker run -d \
  --gpus all \
  -v ollama:/root/.ollama \
  -p 11434:11434 \
  --name ollama \
  ollama/ollama
```

**Pull and run a model:**

```bash
docker exec -it ollama ollama run llama3.2
```

**Call the API:**

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Explain Docker in one sentence."
}'
```

---

## 3. Option B — Hugging Face TGI

Production-grade, high-throughput serving with an OpenAI-compatible endpoint.

```bash
docker run --gpus all --shm-size 1g \
  -p 8080:80 \
  -v $PWD/data:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id mistralai/Mistral-7B-Instruct-v0.2
```

Query it:

```bash
curl http://localhost:8080/generate -X POST \
  -d '{"inputs":"What is a container?","parameters":{"max_new_tokens":100}}' \
  -H 'Content-Type: application/json'
```

> For gated models, pass your token: `-e HF_TOKEN=hf_xxx`.
> 

---

## 4. Option C — vLLM (OpenAI-compatible)

Best throughput; drop-in compatible with the OpenAI API.

```bash
docker run --gpus all \
  -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai:latest \
  --model meta-llama/Llama-3.1-8B-Instruct
```

Use it like the OpenAI API:

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "messages": [{"role":"user","content":"Hello!"}]
  }'
```

---

## 5. Option D — Custom Model Container

When you have your own model/code (e.g., PyTorch + FastAPI).

**`Dockerfile`:**

```dockerfile
FROM pytorch/pytorch:2.4.0-cuda12.4-cudnn9-runtime

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

**`app.py`:**

```python
from fastapi import FastAPI
from pydantic import BaseModel
from transformers import pipeline

app = FastAPI()
pipe = pipeline("text-generation", model="gpt2", device=0)  # device=0 = GPU

class Req(BaseModel):
    prompt: str

@app.post("/generate")
def generate(r: Req):
    return {"output": pipe(r.prompt, max_new_tokens=50)[0]["generated_text"]}
```

**Build and run:**

```bash
docker build -t my-model .
docker run --gpus all -p 8000:8000 my-model
```

---

## 6. Docker Compose Setups

Compose turns long `docker run` commands into a declarative, repeatable file.
Each example below is a complete `docker-compose.yml`.

### 6.1 Ollama + Open WebUI

```yaml
services:
  ollama:
    image: ollama/ollama
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    volumes:
      - openwebui:/app/backend/data
    depends_on:
      - ollama
    restart: unless-stopped

volumes:
  ollama:
  openwebui:
```

```bash
docker compose up -d
docker compose exec ollama ollama pull llama3.2
```

Open `http://localhost:3000` for a ChatGPT-style UI.

### 6.2 Hugging Face TGI

```yaml
services:
  tgi:
    image: ghcr.io/huggingface/text-generation-inference:latest
    container_name: tgi
    ports:
      - "8080:80"
    volumes:
      - ./data:/data
    environment:
      - HF_TOKEN=${HF_TOKEN}       # from .env, for gated models
    command: --model-id mistralai/Mistral-7B-Instruct-v0.2
    shm_size: "1g"                  # required
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

### 6.3 vLLM (OpenAI-compatible)

```yaml
services:
  vllm:
    image: vllm/vllm-openai:latest
    container_name: vllm
    ports:
      - "8000:8000"
    volumes:
      - ~/.cache/huggingface:/root/.cache/huggingface
    environment:
      - HF_TOKEN=${HF_TOKEN}
    command: --model meta-llama/Llama-3.1-8B-Instruct
    ipc: host                       # vLLM recommends host IPC
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

### 6.4 Custom Model (build from Dockerfile)

```yaml
services:
  my-model:
    build: .                        # uses local Dockerfile
    container_name: my-model
    ports:
      - "8000:8000"
    volumes:
      - ./models:/app/models
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

```bash
docker compose up -d --build
```

---

## 7. Managing a Compose Stack

| Command | What it does |
| --- | --- |
| `docker compose up -d` | Start all services in the background |
| `docker compose up -d --build` | Rebuild images, then start |
| `docker compose ps` | List running services |
| `docker compose logs -f <svc>` | Tail logs for one service |
| `docker compose exec <svc> bash` | Shell into a running container |
| `docker compose stop` | Stop without removing containers |
| `docker compose down` | Stop and remove containers/networks |
| `docker compose down -v` | Also remove named volumes (deletes cached models!) |

---

## 8. Best Practices & Gotchas

| Topic | Recommendation |
| --- | --- |
| **Model persistence** | Always mount a volume for weights so they survive restarts and aren't re-downloaded. |
| **Shared memory** | TGI needs `--shm-size 1g` / `shm_size: "1g"`; vLLM prefers `ipc: host`. Skipping causes crashes. |
| **GPU memory** | 7B model ≈ 14 GB FP16, ~5 GB 4-bit quantized. Use quantized (GGUF/AWQ/GPTQ) for smaller GPUs. |
| **Image size** | Prefer `-runtime` base images over `-devel` for production. |
| **Secrets** | Keep tokens in a `.env` file (`HF_TOKEN=...`), reference as `${HF_TOKEN}`. Never hardcode. |
| **CPU fallback** | Drop `--gpus all` / the `deploy` block to run on CPU (slower). |
| **Service networking** | In Compose, services reach each other by name (`http://ollama:11434`), not `localhost`. |
| **Ports** | Ollama `11434`, TGI `8080`, vLLM `8000`. |

---

## 9. Which Should You Pick?

- **Experimenting / local chat** → **Ollama** (simplest; handles downloads + quantization).
- **Serving HF models in production** → **TGI** or **vLLM** (vLLM wins on throughput).
- **Your own custom model/code** → **build your own container**.
- **Multi-service stack (model + UI + proxy)** → **Docker Compose**.
