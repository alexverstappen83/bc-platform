# Bright Cubes Platform

Reproduceerbaar, in Git beheerd Kubernetes-platform (k3s) voor Mac Mini M4,
met visueel beheer, interne DNS en een reverse proxy — alles als **infrastructure
as code**.

## Waarom deze opzet

k3s is Linux-only en bare-metal Linux op de M4 (Asahi) is nog niet bruikbaar.
Daarom draait k3s in een Linux-VM op macOS. Cruciaal: de VM krijgt via **bridged
networking** een écht LAN-IP, zodat MetalLB LoadBalancer-IP's (voor DNS en proxy)
op je hele netwerk bereikbaar zijn. Dat is precies wat bij de eerdere Lima-poging
op user-mode NAT misging.

## Stack (milestone 1)

| Component | Rol | Adres |
|---|---|---|
| UTM + Ubuntu 24.04 | Linux-VM (bridged) | 192.168.124.51 |
| k3s | Kubernetes (cluster-ready) | :6443 |
| MetalLB | LoadBalancer-IP's op het LAN | .60–.70 |
| Traefik | Ingress / reverse proxy | 192.168.124.60 |
| Portainer | Visueel beheer | 192.168.124.62 |
| Technitium | Interne DNS | 192.168.124.61 |

Later: Longhorn, Harbor, Prometheus/Grafana, Authentik, ArgoCD.

## Snel starten

```bash
cp .env.example .env          # pas IP's/wachtwoorden aan
make prereqs                  # check tooling + toon de eenmalige VM-setup
# ... maak de VM eenmalig aan in UTM (zie docs/runbook.md) ...
make up                       # kubeconfig + bootstrap + verify
```

## Documentatie

- [docs/runbook.md](docs/runbook.md) — volledige stap-voor-stap uitrol
- [docs/networking.md](docs/networking.md) — IP-kaart en VIP-toewijzing
- [docs/troubleshooting.md](docs/troubleshooting.md) — veelvoorkomende problemen
- [docs/adding-a-node.md](docs/adding-a-node.md) — extra Mac Mini toevoegen

## Repo-indeling

```
vm/        cloud-init + VM-provisioning (as code)
host/      scripts die op de Mac draaien (via de Makefile)
cluster/   Helm-values + manifests per component (genummerd = installatievolgorde)
docs/      runbook en naslag
```
