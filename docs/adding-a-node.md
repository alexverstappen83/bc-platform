# Een tweede Mac Mini als node toevoegen

Het cluster is bewust **cluster-ready** opgezet (de server draait met
`--cluster-init`, embedded etcd). Een tweede Mac Mini voeg je toe als **agent**
(worker) of als extra **server** (voor HA).

## Randvoorwaarde: bridged netwerk (kabel!)

> **Dit is de kern.** In **NAT**-modus (multipass over wifi) zit elke VM achter
> zijn eigen NAT en kunnen VM's op verschillende Macs elkaar **niet** bereiken —
> een multi-node cluster is dan onmogelijk. Multi-node vereist dat beide VM's een
> **echt LAN-IP** hebben, dus **bridged** via de ethernet-kabel.

Zet daarom eerst **beide** Macs op bridged (zie
[bridged-migratie](#stap-0--zet-node-1-op-bridged) hieronder), en pas daarna
join je node 2.

Controleer op elke Mac welke host-NIC gebrugd kan worden:

```bash
multipass networks
```

Zoek de **ethernet**-interface (op een Mac Mini meestal `en0`); die zetten we in
`.env` als `MULTIPASS_BRIDGE_NIC`.

## Stap 0 — zet node 1 op bridged

De draaiende VM staat in NAT. Een bridged NIC voeg je niet achteraf toe, dus we
bouwen node 1 opnieuw op — alles is IaC, dus dat is één ronde `make`:

```bash
cd ~/bc-platform
# .env aanpassen:
#   NETWORK_MODE=bridged
#   MULTIPASS_BRIDGE_NIC=en0        # jouw ethernet-NIC uit `multipass networks`
make vm-nuke          # verwijdert de NAT-VM (destructief, maar alles is code)
make go               # nieuwe bridged VM + platformlaag (nu MET MetalLB)
make argocd           # ArgoCD + ApplicationSets terug
```

`make go` detecteert nu automatisch het LAN-IP van de VM (het adres in jouw
`192.168.124.x`-range). Lees het af met:

```bash
multipass info k3s-server        # toont het LAN-IPv4 in je eigen subnet
```

Omdat de VM nu een echt LAN-IP heeft, vervallen de socat-forwards
(`make lan-forward`) en zijn Traefik/Technitium/Portainer LAN-breed bereikbaar
via de MetalLB-VIP's. Werk de A-records in Technitium bij naar die VIP's
(zie `docs/dns.md` en `docs/networking.md`).

## Stap 1 — join node 2 als agent (worker)

**Op node 1**, haal het join-token op:

```bash
multipass exec k3s-server -- sudo cat /var/lib/rancher/k3s/server/node-token
```

En het API-IP van node 1 (het LAN-IP uit stap 0), noem dat `<SERVER-LAN-IP>`.

**Op de tweede Mac** (Mac 2): clone de repo, zet in `.env` dezelfde
`NETWORK_MODE=bridged` + `MULTIPASS_BRIDGE_NIC=en0`, en start een **kale**
bridged VM (zonder k3s-server-cloud-init):

```bash
cd ~/bc-platform
multipass launch 24.04 --name k3s-agent \
  --cpus 4 --memory 8G --disk 40G \
  --network name=en0,mode=auto
```

Lees het LAN-IP van deze VM af (`multipass info k3s-agent`, het adres in je
`192.168.124.x`-range) → `<AGENT-LAN-IP>`. Zoek in de VM de naam van de
gebrugde NIC (die met dat LAN-IP):

```bash
multipass exec k3s-agent -- ip -4 -o addr show | grep 192.168.124
```

Join dan als agent, **in de agent-VM**:

```bash
multipass exec k3s-agent -- sudo bash -c '
  export K3S_URL="https://<SERVER-LAN-IP>:6443"
  export K3S_TOKEN="<TOKEN-UIT-node-token>"
  export INSTALL_K3S_EXEC="agent --node-ip=<AGENT-LAN-IP> --flannel-iface=<NIC-NAAM>"
  curl -sfL https://get.k3s.io | sh -
'
```

> `vm/provision/install-k3s-agent.sh.tmpl` bevat dezelfde stappen als kopieerbaar
> template; vul `K3S_URL`, `K3S_TOKEN`, `NODE_IP` en `NIC` in.

## Als extra server (HA) joinen

Wil je node 2 als **server** (voor HA i.p.v. een worker), draai dan in de
agent-VM in plaats daarvan:

```bash
multipass exec k3s-agent -- sudo bash -c '
  export K3S_TOKEN="<TOKEN>"
  export INSTALL_K3S_EXEC="server --server https://<SERVER-LAN-IP>:6443 \
    --node-ip=<AGENT-LAN-IP> --flannel-iface=<NIC-NAAM> \
    --disable=traefik --disable=servicelb --write-kubeconfig-mode=0644"
  curl -sfL https://get.k3s.io | sh -
'
```

> HA met embedded etcd vereist uiteindelijk een **oneven** aantal servers (3).
> Met 2 servers heb je nog geen etcd-quorum-winst; begin dus met een agent, of
> plan meteen een derde node.

## Controleren

Vanaf de Mac met de kubeconfig:

```bash
kubectl get nodes -o wide     # de nieuwe node verschijnt als Ready
```

MetalLB, Traefik, Portainer en Technitium hoef je niet opnieuw te installeren —
die draaien clusterbreed en plannen automatisch mee op de nieuwe node.

## Aandachtspunten

- **DHCP-reservering:** geef beide VM-LAN-IP's een vaste reservering in je router
  (op MAC-adres), anders verspringen de adressen en klopt de join/DNS niet meer.
- **Firewall/segment:** beide Macs moeten in hetzelfde LAN-segment zitten en
  poorten 6443 (API) + 8472/udp (flannel VXLAN) + 10250 (kubelet) onderling
  kunnen bereiken.
- **Kubeconfig blijft op node 1 wijzen** (`<SERVER-LAN-IP>:6443`); de agent heeft
  geen eigen API-endpoint.
