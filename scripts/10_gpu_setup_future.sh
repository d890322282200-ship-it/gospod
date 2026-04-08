#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] Run as root: sudo bash scripts/10_gpu_setup_future.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends ubuntu-drivers-common pciutils

echo "[INFO] Detecting recommended NVIDIA driver"
ubuntu-drivers devices || true

RECOMMENDED_DRIVER="$(ubuntu-drivers devices 2>/dev/null | awk '/recommended/ {print $3; exit}')"
if [[ -z "${RECOMMENDED_DRIVER}" ]]; then
  echo "[WARN] Could not auto-detect recommended driver. Installing generic nvidia-driver-550."
  apt-get install -y nvidia-driver-550 || true
else
  echo "[INFO] Installing ${RECOMMENDED_DRIVER}"
  apt-get install -y "${RECOMMENDED_DRIVER}"
fi

echo "[INFO] Driver install step finished. Reboot is usually required."
echo "[INFO] After reboot run: nvidia-smi"

echo "[INFO] Ollama GPU verification notes:"
echo "  1) Start generation request"
echo "  2) Run nvidia-smi and check GPU memory/process"
echo "  3) Check logs: journalctl -u ollama -f"
