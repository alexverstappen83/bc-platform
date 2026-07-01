#!/usr/bin/env bash
# Haalt de k3s kubeconfig uit de VM en herschrijft 127.0.0.1 -> het VM-IP,
# zodat kubectl vanaf de Mac het cluster kan bereiken.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env

DEST="${REPO_ROOT}/kubeconfig"

info "Kubeconfig ophalen van ${SSH_USER}@${VM_IP} ..."
ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${VM_IP}" \
  'sudo cat /etc/rancher/k3s/k3s.yaml' > "${DEST}"

# k3s schrijft altijd https://127.0.0.1:6443 -> herschrijven is verplicht.
# -i.bak werkt op zowel BSD (macOS) als GNU sed.
sed -i.bak "s#https://127.0.0.1:6443#https://${VM_IP}:6443#" "${DEST}"
rm -f "${DEST}.bak"
chmod 600 "${DEST}"

if kubectl get nodes >/dev/null 2>&1; then
  ok "Kubeconfig werkt:"
  kubectl get nodes
else
  err "Kubeconfig opgehaald, maar cluster niet bereikbaar."
  err "Checks: draait de VM? Is k3s Ready? Klopt VM_IP (${VM_IP})?"
  exit 1
fi
