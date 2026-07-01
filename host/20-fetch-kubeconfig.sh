#!/usr/bin/env bash
# Haalt de k3s kubeconfig uit de VM en herschrijft 127.0.0.1 -> het VM-IP,
# zodat kubectl vanaf de Mac het cluster kan bereiken.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env

DEST="${REPO_ROOT}/kubeconfig"

if [ "${VM_PROVIDER:-multipass}" = "multipass" ]; then
  VMIP="$(detect_vm_ip)"
  [ -n "$VMIP" ] || { err "Kon het VM-IP niet vinden via multipass. Draait de VM? (make vm)"; exit 1; }
  info "Kubeconfig ophalen uit multipass-VM (${VMIP})..."
  multipass exec k3s-server -- sudo cat /etc/rancher/k3s/k3s.yaml > "${DEST}"
else
  VMIP="${VM_IP}"
  info "Kubeconfig ophalen van ${SSH_USER}@${VMIP} ..."
  ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${VMIP}" \
    'sudo cat /etc/rancher/k3s/k3s.yaml' > "${DEST}"
fi

# k3s schrijft altijd https://127.0.0.1:6443 -> herschrijven is verplicht.
# -i.bak werkt op zowel BSD (macOS) als GNU sed.
sed -i.bak "s#https://127.0.0.1:6443#https://${VMIP}:6443#" "${DEST}"
rm -f "${DEST}.bak"
chmod 600 "${DEST}"

if kubectl get nodes >/dev/null 2>&1; then
  ok "Kubeconfig werkt:"
  kubectl get nodes
else
  err "Kubeconfig opgehaald, maar cluster niet bereikbaar (VM-IP: ${VMIP})."
  exit 1
fi
