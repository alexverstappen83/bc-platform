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

# Nette logging.
info()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m! %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Vereist commando ontbreekt: $1"; return 1; }
}
