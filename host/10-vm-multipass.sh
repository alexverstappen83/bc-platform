#!/usr/bin/env bash
# Start de k3s-server VM via multipass (NAT — werkt over wifi, geen kabel nodig).
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env
require_cmd multipass

NAME=k3s-server

# Bridged of NAT?
#  - MULTIPASS_BRIDGE_NIC leeg  -> NAT (standaard, werkt over wifi, single-node)
#  - MULTIPASS_BRIDGE_NIC gezet -> VM krijgt een 2e, GEBRUGDE NIC met een echt
#    LAN-IP. Nodig voor MetalLB én voor een multi-node cluster over meerdere
#    Macs. Zet 'm op de bekabelde ethernet-interface van de Mac (zie:
#    `multipass networks`, bijv. `en0`).
BRIDGE_ARGS=()
if [ -n "${MULTIPASS_BRIDGE_NIC:-}" ]; then
  info "Bridged modus: VM krijgt een LAN-IP via host-NIC '${MULTIPASS_BRIDGE_NIC}'."
  BRIDGE_ARGS=(--network "name=${MULTIPASS_BRIDGE_NIC},mode=auto")
fi

if multipass info "$NAME" >/dev/null 2>&1; then
  ok "VM '${NAME}' bestaat al."
  [ -n "${MULTIPASS_BRIDGE_NIC:-}" ] && warn "Bestaande VM: een bridged NIC voeg je niet achteraf toe. Voor bridged eerst 'make vm-nuke' en opnieuw 'make go'."
else
  info "VM '${NAME}' aanmaken (Ubuntu 24.04 + k3s via cloud-init)..."
  info "De eerste keer downloadt multipass het image (~300 MB) — even geduld."
  multipass launch 24.04 --name "$NAME" \
    --cpus 4 --memory 8G --disk 40G \
    "${BRIDGE_ARGS[@]}" \
    --cloud-init vm/cloud-init/multipass.yaml
fi

info "Wachten tot k3s Ready is (cloud-init installeert nog)..."
for _ in $(seq 1 60); do
  if multipass exec "$NAME" -- sudo k3s kubectl get nodes 2>/dev/null | grep -q ' Ready '; then
    ok "k3s node Ready"
    VMIP="$(detect_vm_ip)"
    ok "VM-IP: ${VMIP}"
    exit 0
  fi
  sleep 5
done
err "k3s werd niet Ready binnen de tijd."
err "Kijk met:  multipass exec ${NAME} -- sudo journalctl -u k3s -n 50 --no-pager"
exit 1
