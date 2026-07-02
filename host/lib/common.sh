# shellcheck shell=bash
# Gedeelde helpers voor de host-scripts. Source dit bestand, voer het niet uit.
set -euo pipefail

# Repo-root bepalen (dit bestand staat in host/lib/).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Config laden: .env overschrijft de defaults uit .env.example.
load_env() {
  set -a
  # shellcheck disable=SC1091
  [ -f "${REPO_ROOT}/.env.example" ] && . "${REPO_ROOT}/.env.example"
  # shellcheck disable=SC1091
  [ -f "${REPO_ROOT}/.env" ] && . "${REPO_ROOT}/.env"
  set +a
}

# Alle kubectl/helm-commando's gebruiken de opgehaalde kubeconfig.
export KUBECONFIG="${REPO_ROOT}/kubeconfig"

# Bepaal het IP van de VM, afhankelijk van de provider.
#  - multipass : dynamisch via `multipass info`
#  - utm/anders: het VM_IP uit .env (statisch of door jou ingevuld)
#
# In bridged-modus heeft de multipass-VM TWEE IPv4's: de NAT-adapter (eerst) en
# de gebrugde LAN-adapter. We willen dan het LAN-IP. Dat filteren we op het
# subnet van HOST_IP (eerste drie octetten), zodat de forwards en records naar
# het juiste adres wijzen. In NAT-modus is er maar één IPv4 → gewoon de eerste.
detect_vm_ip() {
  case "${VM_PROVIDER:-multipass}" in
    multipass)
      local ips prefix
      ips="$(multipass info k3s-server 2>/dev/null | awk '/IPv4/{print $2} /^ +[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/{print $1}')"
      if [ "${NETWORK_MODE:-nat}" = "bridged" ] && [ -n "${HOST_IP:-}" ]; then
        prefix="${HOST_IP%.*}."
        echo "$ips" | grep -F "$prefix" | head -n1
      else
        echo "$ips" | head -n1
      fi
      ;;
    *) echo "${VM_IP:-}" ;;
  esac
}

# Nette logging.
info()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m! %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Vereist commando ontbreekt: $1"; return 1; }
}
