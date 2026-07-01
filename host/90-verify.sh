#!/usr/bin/env bash
# Geautomatiseerde health-checks per laag + de handmatige LAN-checks.
set -uo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env

fail=0
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else err "$1"; fail=1; fi; }

info "Verificatie per laag..."
check "kubeconfig aanwezig" "[ -f '${KUBECONFIG}' ]"
check "node Ready" "kubectl get nodes | grep -q ' Ready '"
check "MetalLB controller up" \
  "kubectl -n metallb-system get deploy metallb-controller -o jsonpath='{.status.availableReplicas}' | grep -q '^[1-9]'"
check "IPAddressPool aanwezig" "kubectl -n metallb-system get ipaddresspool lan-pool"
check "Traefik VIP = ${TRAEFIK_IP}" \
  "kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -q '${TRAEFIK_IP}'"
check "Portainer VIP = ${PORTAINER_IP}" \
  "kubectl -n portainer get svc portainer -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -q '${PORTAINER_IP}'"
check "Technitium VIP = ${TECHNITIUM_IP}" \
  "kubectl -n technitium get svc technitium-dns -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -q '${TECHNITIUM_IP}'"

echo
info "Handmatige checks (bij voorkeur vanaf een ander toestel op je LAN):"
echo "  curl -I http://${TRAEFIK_IP}"
echo "  open  http://${PORTAINER_IP}:9000"
echo "  dig @${TECHNITIUM_IP} portainer.${DOMAIN} +short"

echo
if [ "$fail" -eq 0 ]; then
  ok "Alle geautomatiseerde checks OK"
else
  err "Sommige checks faalden — zie docs/troubleshooting.md"
  exit 1
fi
