#!/usr/bin/env bash
set -euo pipefail

SMALL_MODEL="${SMALL_MODEL:-qwen2.5-coder:1.5b}"
MAIN_MODEL="${MAIN_MODEL:-qwen2.5-coder:14b}"
OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"

if ! command -v ollama >/dev/null 2>&1; then
  echo "[ERROR] ollama command not found. Install first."
  exit 1
fi

if ! curl -fsS "${OLLAMA_HOST}/api/version" >/dev/null; then
  echo "[ERROR] Ollama API is not reachable at ${OLLAMA_HOST}"
  exit 1
fi

echo "[INFO] Pulling SMALL_MODEL=${SMALL_MODEL}"
ollama pull "${SMALL_MODEL}"

echo "[INFO] Pulling MAIN_MODEL=${MAIN_MODEL}"
ollama pull "${MAIN_MODEL}" || {
  echo "[WARN] Failed to pull MAIN_MODEL=${MAIN_MODEL}."
  echo "[WARN] This is expected on low-RAM/CPU machines or if model tag is unavailable."
}

echo "[INFO] Installed models:"
ollama list || true
