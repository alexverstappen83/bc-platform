#!/usr/bin/env bash
# Controleert de tooling op de Mac en toont de eenmalige VM-setup in UTM.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env

info "Controleer benodigde tooling op de Mac..."
missing=0
for c in brew kubectl helm ssh dig; do
  if command -v "$c" >/dev/null 2>&1; then ok "$c aanwezig"; else warn "$c ontbreekt"; missing=1; fi
done

if [ -d "/Applications/UTM.app" ] || command -v utmctl >/dev/null 2>&1; then
  ok "UTM aanwezig"
else
  warn "UTM ontbreekt  ->  brew install --cask utm"; missing=1
fi

if command -v mkisofs >/dev/null 2>&1 || command -v hdiutil >/dev/null 2>&1; then
  ok "ISO-tool aanwezig"
else
  warn "Geen ISO-tool  ->  brew install cdrtools"; missing=1
fi

echo
if [ "$missing" -ne 0 ]; then
  cat <<'EOF'
Installeer de ontbrekende tools, bijvoorbeeld:
  brew install kubectl helm bind        # bind levert 'dig'
  brew install --cask utm
  brew install cdrtools                  # levert 'mkisofs' (optioneel; hdiutil kan ook)
EOF
else
  ok "Alle tooling aanwezig."
fi

cat <<EOF

Eenmalige VM-setup (grafisch in UTM) — details in docs/runbook.md:
  1) Pas vm/cloud-init/user-data aan: plak je SSH-key en check IP/gateway.
  2) make seed                                   # bouwt vm/seed.iso
  3) Download de Ubuntu 24.04 arm64 cloud image (.img).
  4) UTM -> Virtualize -> Linux -> gebruik het cloud image als disk,
     koppel vm/seed.iso als TWEEDE drive.
  5) Netwerk = Bridged (Advanced), gekoppeld aan je bekabelde poort (en0).
  6) 4 CPU / 8 GB RAM / 60 GB disk -> start de VM.
  7) Wacht tot dit werkt:  ssh ${SSH_USER}@${VM_IP}
  8) Dan op de Mac:        make up
EOF
