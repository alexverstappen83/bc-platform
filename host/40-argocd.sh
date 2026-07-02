#!/usr/bin/env bash
# Installeert ArgoCD + de DTAP-namespaces + AppProject + ApplicationSets.
# Draai dit op de Mac nadat het cluster staat (make up).
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env
require_cmd kubectl
require_cmd helm
[ -f "${KUBECONFIG}" ] || { err "Geen kubeconfig. Draai eerst: make kubeconfig"; exit 1; }

info "DTAP-namespaces toepassen (ontwikkel / test-acceptatie / productie)..."
kubectl apply -f cluster/40-namespaces/

info "ArgoCD installeren..."
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  -f cluster/80-argocd/values.yaml --wait

info "AppProject + ApplicationSets toepassen..."
kubectl apply -f cluster/80-argocd/project.yaml
kubectl apply -f cluster/80-argocd/applicationset-auto.yaml
kubectl apply -f cluster/80-argocd/applicationset-prod.yaml

ok "ArgoCD klaar."
echo
echo "== ArgoCD admin-wachtwoord =="
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d; echo
cat <<'EOF'

UI openen (NAT-modus) — op de Mac Mini:
  kubectl port-forward --address 0.0.0.0 -n argocd svc/argocd-server 8080:80
Dan op je MacBook: http://<mac-mini-lan-ip>:8080   (login: admin / bovenstaand wachtwoord)

LET OP: als bc-platform een PRIVATE repo is, moet ArgoCD toegang krijgen tot de
repo (anders kan de ApplicationSet de app-mappen niet lezen). Zie docs/cicd.md.
EOF
