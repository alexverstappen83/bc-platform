#!/usr/bin/env bash
# Bouwt vm/seed.iso met cloud-init, afhankelijk van NETWORK_MODE (nat|bridged).
# De SSH-key wordt automatisch uit ~/.ssh/id_ed25519.pub gehaald — geen handwerk.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=host/lib/common.sh
source host/lib/common.sh
load_env
: "${NETWORK_MODE:=nat}"
: "${VM_IP:=192.168.124.51}"
: "${LAN_GATEWAY:=192.168.124.1}"
: "${VM_NIC:=enp0s1}"

SSH_KEY="$(cat "${HOME}/.ssh/id_ed25519.pub" 2>/dev/null || true)"
[ -n "$SSH_KEY" ] || { err "Geen SSH-key gevonden (~/.ssh/id_ed25519.pub)."; \
  err "Maak er een met:  ssh-keygen -t ed25519"; exit 1; }

BUILD="vm/.build"; mkdir -p "$BUILD"
cp vm/cloud-init/meta-data "$BUILD/meta-data"

info "cloud-init genereren voor NETWORK_MODE=${NETWORK_MODE}"
if [ "$NETWORK_MODE" = "bridged" ]; then
  cat > "$BUILD/user-data" <<EOF
#cloud-config
hostname: k3s-server
manage_etc_hosts: true
users:
  - name: ubuntu
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
      - "${SSH_KEY}"
package_update: true
packages: [curl, open-iscsi]
write_files:
  - path: /etc/netplan/99-bc-static.yaml
    permissions: "0600"
    content: |
      network:
        version: 2
        ethernets:
          ${VM_NIC}:
            dhcp4: false
            addresses: [${VM_IP}/24]
            routes:
              - to: default
                via: ${LAN_GATEWAY}
            nameservers:
              addresses: [${LAN_GATEWAY}, 1.1.1.1]
runcmd:
  - netplan apply
  - sleep 3
  - export INSTALL_K3S_EXEC="server --node-ip=${VM_IP} --advertise-address=${VM_IP} --flannel-iface=${VM_NIC} --tls-san=${VM_IP} --tls-san=k3s-server --disable=traefik --disable=servicelb --write-kubeconfig-mode=0644 --cluster-init"; curl -sfL https://get.k3s.io | sh -
final_message: "bc-platform k3s (bridged) klaar. IP: ${VM_IP}"
EOF
else
  cat > "$BUILD/user-data" <<EOF
#cloud-config
hostname: k3s-server
manage_etc_hosts: true
users:
  - name: ubuntu
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
      - "${SSH_KEY}"
package_update: true
packages: [curl, open-iscsi]
runcmd:
  - export INSTALL_K3S_EXEC="server --disable=traefik --write-kubeconfig-mode=0644 --cluster-init"; curl -sfL https://get.k3s.io | sh -
final_message: "bc-platform k3s (nat) klaar. Bekijk het VM-IP met: ip -4 addr show"
EOF
fi

OUT="vm/seed.iso"
if command -v mkisofs >/dev/null 2>&1; then
  mkisofs -output "$OUT" -volid cidata -joliet -rock "$BUILD/user-data" "$BUILD/meta-data"
elif command -v cloud-localds >/dev/null 2>&1; then
  cloud-localds "$OUT" "$BUILD/user-data" "$BUILD/meta-data"
elif command -v hdiutil >/dev/null 2>&1; then
  rm -rf "$BUILD/iso" && mkdir -p "$BUILD/iso"
  cp "$BUILD/user-data" "$BUILD/meta-data" "$BUILD/iso/"
  hdiutil makehybrid -o "$OUT" -iso -joliet -default-volume-name cidata "$BUILD/iso"
  rm -rf "$BUILD/iso"
else
  err "Geen ISO-tool gevonden. Installeer:  brew install cdrtools"; exit 1
fi

ok "${PWD}/${OUT} gebouwd (mode=${NETWORK_MODE}). Koppel dit in UTM als tweede drive."
