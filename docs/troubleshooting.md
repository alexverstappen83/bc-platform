# Troubleshooting

De drie meest waarschijnlijke problemen bij deze opzet, met oplossing.

## 1. Services niet bereikbaar op het LAN (MetalLB-VIP's dood)

**Symptoom:** `kubectl get svc -A` toont wel EXTERNAL-IP's, maar `ping`/`curl`
vanaf een ander toestel naar `.60/.61/.62` doet niets.

**Oorzaak:** de VM zit niet écht op het LAN (NAT i.p.v. bridged) — dít is wat de
vorige Lima-poging brak. MetalLB L2 kan dan geen ARP announcen.

**Controle & fix:**
```bash
ssh ubuntu@192.168.124.51 ip -4 addr show     # moet 192.168.124.51 tonen op enp0s1
```
- Staat er een `192.168.124.x`? Dan is bridged goed.
- Staat er `192.168.64.x` of `10.x`? → VM staat op NAT. In UTM: **Network → Mode
  = Bridged (Advanced)**, gekoppeld aan je bekabelde poort. Herstart de VM.
- Bridged werkt het betrouwbaarst over **bekabeld ethernet**; wifi-bridging is
  vaak geblokkeerd.

## 2. `kubectl` verbindt niet / verkeerde NIC-naam

**Symptoom:** `make kubeconfig` faalt, of kubectl loopt vast op `127.0.0.1:6443`.

**Fixes:**
- De kubeconfig moet naar `192.168.124.51:6443` wijzen. `20-fetch-kubeconfig.sh`
  herschrijft dit automatisch; controleer met
  `grep server ./kubeconfig`.
- Is de NIC in de VM geen `enp0s1`? Kijk met `ssh ubuntu@192.168.124.51 ip a`.
  Pas de naam aan op **twee plekken** en start opnieuw:
  - `vm/cloud-init/user-data` (netplan `ethernets:` én `--flannel-iface`),
  - `.env` (`VM_NIC=`).
  k3s bindt `--flannel-iface`/`--node-ip` aan die NIC; klopt de naam niet, dan
  registreert de node op het verkeerde adres.

## 3. MetalLB-fout bij bootstrap of DNS-service geweigerd

**MetalLB webhook-race:** CR's te vroeg toegepast. `30-bootstrap.sh` doet
`kubectl wait` op `metallb-controller` vóór de pool. Handmatig opnieuw:
```bash
kubectl wait --for=condition=Available deploy/metallb-controller \
  -n metallb-system --timeout=120s
kubectl apply -f cluster/00-metallb/config/
```

**Technitium TCP+UDP op één VIP geweigerd:** moderne k3s ondersteunt mixed
protocol prima. Weigert je cluster het toch, splits dan in twee Services die de
VIP delen via `metallb.universe.tf/allow-shared-ip: "technitium-dns"` (zet dezelfde
annotatie op beide). De web-UI-service (`technitium-web`, ClusterIP) blijft
ongewijzigd.

## Algemene diagnose

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get svc -A
kubectl -n metallb-system logs -l app.kubernetes.io/component=speaker
ssh ubuntu@192.168.124.51 sudo journalctl -u k3s -n 100 --no-pager
```

## VM opnieuw beginnen

```bash
make vm-nuke          # verwijdert de VM
make seed             # opnieuw seed bouwen (na aanpassing user-data)
# ... VM opnieuw aanmaken in UTM (docs/runbook.md §2) ...
```
