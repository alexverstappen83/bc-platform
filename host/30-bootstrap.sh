#!/usr/bin/env bash
# Installeert de platformlaag in vaste volgorde:
#   MetalLB -> Traefik -> Portainer -> Technitium DNS
# Idempotent: opnieuw draaien is veilig (helm upgrade --install / kubectl apply).
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env

require_cmd kubectl
require_cmd helm
[ -f "${KUBECONFIG}" ] || { err "Geen kubeconfig. Draai eerst: make kubeconfig"; exit 1; }

info "Helm-repos toevoegen/bijwerken..."
helm repo add metallb   https://metallb.github.io/metallb  >/dev/null 2>&1 || true
helm repo add traefik   https://traefik.github.io/charts   >/dev/null 2>&1 || true
helm repo add portainer https://portainer.github.io/k8s/   >/dev/null 2>&1 || true
helm repo update >/dev/null

# --- 1) MetalLB -------------------------------------------------------------
info "MetalLB installeren..."
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system --create-namespace \
  -f cluster/00-metallb/values.yaml --wait
info "Wachten op de MetalLB controller (webhook) voordat we CR's toepassen..."
kubectl wait --for=condition=Available deploy/metallb-controller \
  -n metallb-system --timeout=120s
kubectl -n metallb-system rollout status ds/metallb-speaker --timeout=120s
info "IPAddressPool + L2Advertisement toepassen..."
kubectl apply -f cluster/00-metallb/config/
ok "MetalLB klaar"

# --- 2) Traefik -------------------------------------------------------------
info "Traefik (ingress + LoadBalancer) installeren..."
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  -f cluster/10-traefik/values.yaml --wait
ok "Traefik klaar"

# --- 3) Portainer -----------------------------------------------------------
info "Portainer (visueel beheer) installeren..."
helm upgrade --install portainer portainer/portainer \
  --namespace portainer --create-namespace \
  -f cluster/20-portainer/values.yaml --wait
kubectl apply -f cluster/20-portainer/manifests/
ok "Portainer klaar"

# --- 4) Technitium DNS ------------------------------------------------------
info "Technitium DNS installeren..."
kubectl apply -f cluster/30-technitium/manifests/namespace.yaml
# admin-wachtwoord als secret (idempotent, komt uit .env)
kubectl create secret generic technitium-admin \
  --namespace technitium \
  --from-literal=password="${TECHNITIUM_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f cluster/30-technitium/manifests/
ok "Technitium klaar"

echo
ok "Bootstrap voltooid. Controleer met: make verify"
cat <<EOF

Toegang (zolang DNS nog niet is ingesteld: via IP):
  Portainer  : http://${PORTAINER_IP}:9000    <-- zet HIER meteen een admin-wachtwoord!
  Traefik    : http://${TRAEFIK_IP}
  DNS web-UI : http://${TECHNITIUM_IP}:5380    (login: admin / <wachtwoord uit .env>)
  DNS-server : ${TECHNITIUM_IP}:53

Daarna in Technitium: maak zone '${DOMAIN}' met A-records
  traefik/portainer/dns  ->  bijbehorende VIP, en zet je router-DNS op ${TECHNITIUM_IP}.
EOF
