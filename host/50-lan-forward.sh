#!/usr/bin/env bash
# LAN-toegang in NAT-modus (tijdelijk, tot je bekabeld/bridged gaat).
# Forwardt van de Mac naar de services in de VM, met auto-herstart:
#   - DNS  op :5354  (niet-privileged -> geen sudo)
#   - HTTP op :80    (privileged -> draai dit script met sudo voor deze poort)
#
# LET OP: een oude Lima-VM kan poort 80 bezet houden. Controleer met
#   sudo lsof -nP -iTCP:80 -sTCP:LISTEN
# en stop 'm zo nodig met  limactl stop <naam>  (of  limactl delete <naam>).
set -uo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env
require_cmd socat

VM="$(detect_vm_ip)"
[ -n "$VM" ] || { err "VM-IP niet gevonden (draait multipass?)"; exit 1; }
info "LAN-forward -> VM ${VM}: DNS op :5354, HTTP op :80"

pkill -f "bc-lanfwd" 2>/dev/null || true
sleep 1

keepalive() { # naam  socat-args...
  local name="$1"; shift
  nohup bash -c "while true; do socat $*; sleep 2; done # bc-lanfwd-${name}" \
    >"${HOME}/bc-lanfwd-${name}.log" 2>&1 &
}

keepalive dns-udp "UDP-LISTEN:5354,fork,reuseaddr UDP:${VM}:53"
keepalive dns-tcp "TCP-LISTEN:5354,fork,reuseaddr TCP:${VM}:53"

if [ "$(id -u)" = "0" ]; then
  keepalive http "TCP-LISTEN:80,fork,reuseaddr TCP:${VM}:80"
  ok "DNS (:5354) + HTTP (:80) forwards gestart."
else
  warn "HTTP :80 overgeslagen (geen root). Voor poort 80:  sudo $0"
  ok "DNS (:5354) forward gestart."
fi

echo
info "Zie docs/dns.md voor de zone-config en de /etc/resolver-stap op je clients."
