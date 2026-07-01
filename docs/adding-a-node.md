# Een extra node toevoegen

Het cluster is bewust **cluster-ready** opgezet (de server draaide met
`--cluster-init`, embedded etcd). Een tweede Mac Mini voeg je toe als **agent**
(worker) of als extra **server** (voor HA).

## Voorbereiding

Haal op de bestaande server het join-token op:

```bash
ssh ubuntu@192.168.124.51 sudo cat /var/lib/rancher/k3s/server/node-token
```

Maak op de nieuwe Mac een VM op dezelfde manier als node 1
(docs/runbook.md §1–2), maar geef hem een **eigen statisch IP**, bijv.
`192.168.124.52`. Pas in `vm/cloud-init/user-data` het `addresses:`-veld aan
(of gebruik een aparte kopie van de seed).

## Als agent (worker) joinen

Kopieer de template en vul in, draai dit **in de nieuwe VM**:

```bash
cp vm/provision/install-k3s-agent.sh.tmpl install-k3s-agent.sh
# vul K3S_TOKEN en NODE_IP (bv. 192.168.124.52) in
sudo bash install-k3s-agent.sh
```

## Als extra server (HA) joinen

Draai in de nieuwe VM in plaats daarvan:

```bash
export K3S_TOKEN="<token>"
export INSTALL_K3S_EXEC="server --server https://192.168.124.51:6443 \
  --node-ip=192.168.124.52 --flannel-iface=enp0s1 \
  --disable=traefik --disable=servicelb --write-kubeconfig-mode=0644"
curl -sfL https://get.k3s.io | sh -
```

> HA met embedded etcd vereist uiteindelijk een **oneven** aantal servers (3).

## Controleren

Vanaf de Mac:

```bash
kubectl get nodes -o wide     # de nieuwe node verschijnt als Ready
```

MetalLB, Traefik, Portainer en Technitium hoef je niet opnieuw te installeren —
die draaien clusterbreed en plannen automatisch mee op de nieuwe node.
