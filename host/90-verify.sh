#!/usr/bin/env bash
# Geautomatiseerde health-checks per laag + de handmatige toegang-checks.
set -uo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env
: "${NETWORK_MODE:=nat}"

fail=0
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else err "$1"; fail=1; fi; }

# Verwachte LoadBalancer-IP's per modus:
#  - bridged: de gepinde MetalLB-VIP's (.60/.61/.62)
#  - nat    : k3s servicelb geeft alle services het VM-IP zelf
if [ "$NETWORK_MODE" = "bridged" ]; then
  EXP_TRAEFIK="$TRAEFIK_IP"; EXP_PORTAINER="$PORTAINER_IP"; EXP_TECHNITIUM="$TECHNITIUM_IP"
else
  EXP_TRAEFIK="$VM_IP"; EXP_PORTAINER="$VM_IP"; EXP_TECHNITIUM="$VM_IP"
fi

info "Verificatie per laag (mode=${NETWORK_MODE})..."
check "kubeconfig aanwezig" "[ -f '${KUBECONFIG}' ]"
check "node Ready" "kubectl get nodes | grep -q ' Ready '"
if [ "$NETWORK_MODE" = "bridged" ]; then
  check "MetalLB controller up" \
    "kubectl -n metallb-system get deploy metallb-controller -o jsonpath='{.status.availableReplicas}' | grep -q '^[1-9]'"
  check "IPAddressPool aanwezig" "kubectl -n metallb-system get ipaddresspool lan-pool"
fi
check "Traefik LB = ${EXP_TRAEFIK}" \
  "kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -q '${EXP_TRAEFIK}'"
check "Portainer LB = ${EXP_PORTAINER}" \
  "kubectl -n portainer get svc portainer -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -q '${EXP_PORTAINER}'"
check "Technitium LB = ${EXP_TECHNITIUM}" \
  "kubectl -n technitium get svc technitium-dns -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -q '${EXP_TECHNITIUM}'"

echo
info "Toegang (vanaf deze Mac):"
echo "  Portainer : http://${EXP_PORTAINER}:9000   (zet meteen een admin-wachtwoord!)"
echo "  Traefik   : http://${EXP_TRAEFIK}"
echo "  DNS web-UI: http://${EXP_TECHNITIUM}:5380"
echo "  DNS test  : dig @${EXP_TECHNITIUM} example.com +short"
if [ "$NETWORK_MODE" = "nat" ]; then
  echo
  info "NAT-modus: bovenstaande werkt vanaf deze Mac. Voor andere apparaten op je"
  info "LAN (router-DNS, enz.) is een netwerkkabel + bridged-modus nodig — later."
fi

echo
if [ "$fail" -eq 0 ]; then
  ok "Alle geautomatiseerde checks OK"
else
  err "Sommige checks faalden — zie docs/troubleshooting.md"
  exit 1
fi
