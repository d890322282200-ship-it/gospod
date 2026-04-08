#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] Run as root: sudo bash scripts/00_base.sh"
  exit 1
fi

SERVICE_USER="aiops"
SERVICE_GROUP="aiops"
REPO_ROOT="/srv/ai/repos"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl wget git jq unzip \
  build-essential python3 python3-venv python3-pip \
  gnupg lsb-release software-properties-common \
  openssh-client ufw

if ! getent group "${SERVICE_GROUP}" >/dev/null 2>&1; then
  groupadd --system "${SERVICE_GROUP}"
  echo "[INFO] Group ${SERVICE_GROUP} created"
else
  echo "[INFO] Group ${SERVICE_GROUP} already exists"
fi

if ! id -u "${SERVICE_USER}" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir /home/${SERVICE_USER} \
    --shell /bin/bash --gid "${SERVICE_GROUP}" "${SERVICE_USER}"
  echo "[INFO] User ${SERVICE_USER} created"
else
  echo "[INFO] User ${SERVICE_USER} already exists"
fi

mkdir -p /srv/ai
mkdir -p "${REPO_ROOT}"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" /srv/ai
chmod 0750 /srv/ai
chmod 0750 "${REPO_ROOT}"

echo "[INFO] Base setup done"
