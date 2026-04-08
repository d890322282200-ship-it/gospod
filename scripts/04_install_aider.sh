#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] Run as root: sudo bash scripts/04_install_aider.sh"
  exit 1
fi

VENV_PATH="/opt/aider-venv"
WRAPPER_PATH="/usr/local/bin/aider-ollama"

apt-get update
apt-get install -y --no-install-recommends python3 python3-venv python3-pip git curl

if [[ ! -d "${VENV_PATH}" ]]; then
  python3 -m venv "${VENV_PATH}"
fi

"${VENV_PATH}/bin/pip" install --upgrade pip
"${VENV_PATH}/bin/pip" install --upgrade aider-chat

cat > "${WRAPPER_PATH}" <<'EOW'
#!/usr/bin/env bash
set -euo pipefail

MODEL="${MODEL:-qwen2.5-coder:1.5b}"
OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"
AIDER_BIN="/opt/aider-venv/bin/aider"

if [[ ! -x "${AIDER_BIN}" ]]; then
  echo "[ERROR] aider binary not found at ${AIDER_BIN}"
  exit 1
fi

exec "${AIDER_BIN}" \
  --model "ollama/${MODEL}" \
  --ollama-api-base "${OLLAMA_HOST}" \
  "$@"
EOW

chmod +x "${WRAPPER_PATH}"

"${VENV_PATH}/bin/aider" --version
"${WRAPPER_PATH}" --help >/dev/null || true

echo "[INFO] aider installed in ${VENV_PATH}"
echo "[INFO] wrapper installed at ${WRAPPER_PATH}"
