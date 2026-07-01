#!/usr/bin/env bash
# Verwijdert de cluster-resources (de VM zelf blijft draaien).
set -uo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env

warn "Dit verwijdert alle platform-resources uit het cluster (VM blijft bestaan)."
kubectl delete -f cluster/30-technitium/manifests/ --ignore-not-found || true
helm uninstall portainer -n portainer || true
helm uninstall traefik   -n traefik   || true
kubectl delete -f cluster/00-metallb/config/ --ignore-not-found || true
helm uninstall metallb   -n metallb-system || true
ok "Cluster-resources verwijderd."
