#!/usr/bin/env bash
# Bouwt een NoCloud seed.iso uit vm/cloud-init/{user-data,meta-data}.
# Koppel de ISO in UTM als tweede drive; cloud-init leest 'm bij de eerste boot.
set -euo pipefail
cd "$(dirname "$0")"
OUT="seed.iso"

if command -v mkisofs >/dev/null 2>&1; then
  mkisofs -output "${OUT}" -volid cidata -joliet -rock \
    cloud-init/user-data cloud-init/meta-data
elif command -v cloud-localds >/dev/null 2>&1; then
  cloud-localds "${OUT}" cloud-init/user-data cloud-init/meta-data
elif command -v hdiutil >/dev/null 2>&1; then
  # macOS zonder cdrtools: bouw via hdiutil. Het volume MOET 'cidata' heten.
  rm -rf .seed && mkdir -p .seed
  cp cloud-init/user-data cloud-init/meta-data .seed/
  hdiutil makehybrid -o "${OUT}" -iso -joliet -default-volume-name cidata .seed
  rm -rf .seed
else
  echo "Geen ISO-tool gevonden. Installeer:  brew install cdrtools" >&2
  exit 1
fi

echo "✔ ${PWD}/${OUT} gebouwd — koppel dit als tweede drive in UTM."
