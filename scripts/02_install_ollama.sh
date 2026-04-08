#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] Run as root: sudo bash scripts/02_install_ollama.sh"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  apt-get update && apt-get install -y curl
fi

if command -v ollama >/dev/null 2>&1; then
  echo "[INFO] Ollama already installed: $(ollama --version || true)"
else
  curl -fsSL https://ollama.com/install.sh | sh
fi

mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf <<'EOC'
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
EOC

systemctl daemon-reload
systemctl enable --now ollama

sleep 2
systemctl --no-pager --full status ollama || true

if curl -fsS http://127.0.0.1:11434/api/version >/dev/null; then
  echo "[INFO] Ollama API is healthy at 127.0.0.1:11434"
else
  echo "[ERROR] Ollama health check failed"
  exit 1
fi

ss -ltnp | grep 11434 || true
