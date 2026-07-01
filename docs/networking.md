# Netwerk

Vrije LAN-range: `192.168.124.50 – 192.168.124.99`. De Mac zelf is `.50`.

| Onderdeel | IP | Poorten |
|---|---|---|
| Mac host | 192.168.124.50 | — |
| k3s server VM (bridged, statisch) | 192.168.124.51 | 22 (ssh), 6443 (API) |
| MetalLB L2-pool | 192.168.124.60 – .70 | — |
| Traefik (ingress/proxy) | 192.168.124.60 | 80, 443 |
| Technitium DNS | 192.168.124.61 | 53 (udp+tcp), 5380 (ui) |
| Portainer | 192.168.124.62 | 9000 |
| Vrij voor later | 192.168.124.63 – .70 | — |
| Gateway (verifiëren!) | 192.168.124.1 | — |

## Principes

- **Bridged VM** → de node ARP-announceert VIP's op hetzelfde segment; daarom
  werkt MetalLB L2 en zijn DNS/proxy op het hele LAN bereikbaar.
- **Gepinde VIP's** via `metallb.universe.tf/loadBalancerIPs`, zodat DNS-records
  stabiel blijven.
- Zorg dat `.51` en `.60–.70` **buiten je DHCP-range** vallen om conflicten te
  voorkomen (controleer je router).

## Interne DNS-zone

Maak in Technitium een primaire zone `home.brightcubes.nl`:

| Record | Type | Waarde |
|---|---|---|
| traefik | A | 192.168.124.60 |
| portainer | A | 192.168.124.60 |
| dns | A | 192.168.124.60 |

De services staan achter Traefik (ingress) op `.60`; DNS wijst de hostnames dus
naar `.60`. Zet daarna de DNS van je router (of per apparaat) op `192.168.124.61`.
