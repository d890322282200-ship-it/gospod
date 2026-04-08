#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] Run as root: sudo bash scripts/01_swap_optional.sh"
  exit 1
fi

SWAPFILE="/swapfile"
SWAPSIZE_GB="${SWAPSIZE_GB:-4}"

if swapon --show | grep -q "${SWAPFILE}"; then
  echo "[INFO] Swap ${SWAPFILE} already active"
  exit 0
fi

if [[ -f "${SWAPFILE}" ]]; then
  echo "[INFO] Swap file exists, activating"
else
  echo "[INFO] Creating ${SWAPSIZE_GB}G swap at ${SWAPFILE}"
  fallocate -l "${SWAPSIZE_GB}G" "${SWAPFILE}" || dd if=/dev/zero of="${SWAPFILE}" bs=1M count=$((SWAPSIZE_GB*1024))
  chmod 600 "${SWAPFILE}"
  mkswap "${SWAPFILE}"
fi

swapon "${SWAPFILE}"

if ! grep -q "^${SWAPFILE} " /etc/fstab; then
  echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
fi

sysctl vm.swappiness=10
sysctl vm.vfs_cache_pressure=50

if ! grep -q '^vm.swappiness=' /etc/sysctl.conf; then
  echo 'vm.swappiness=10' >> /etc/sysctl.conf
else
  sed -i 's/^vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf
fi

if ! grep -q '^vm.vfs_cache_pressure=' /etc/sysctl.conf; then
  echo 'vm.vfs_cache_pressure=50' >> /etc/sysctl.conf
else
  sed -i 's/^vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=50/' /etc/sysctl.conf
fi

echo "[INFO] Swap configured"
free -h
swapon --show
