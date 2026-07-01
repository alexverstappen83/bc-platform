#!/bin/bash
# Canonieke k3s server-install (draait IN de VM).
# cloud-init/user-data bevat een identieke kopie in write_files; houd beide gelijk.
set -euo pipefail

NODE_IP="${NODE_IP:-192.168.124.51}"
NIC="${VM_NIC:-enp0s1}"

export INSTALL_K3S_EXEC="server \
  --node-ip=${NODE_IP} --advertise-address=${NODE_IP} \
  --flannel-iface=${NIC} \
  --tls-san=${NODE_IP} --tls-san=192.168.124.50 --tls-san=k3s-server \
  --disable=traefik --disable=servicelb \
  --write-kubeconfig-mode=0644 --cluster-init"

curl -sfL https://get.k3s.io | sh -

echo "Server draait. Join-URL: https://${NODE_IP}:6443"
echo "Token ophalen: sudo cat /var/lib/rancher/k3s/server/node-token"
