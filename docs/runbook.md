# Runbook — k3s op Mac Mini M4 (milestone 1)

Volg dit één keer om van niets naar een werkend cluster met visueel beheer,
interne DNS en reverse proxy te komen. Alles daarna is `make`-commando's.

## 0. Voorbereiding op de Mac

```bash
cp .env.example .env
# open .env en pas aan: wachtwoorden, en IP's als je netwerk afwijkt
make prereqs
```

`make prereqs` installeert niets, maar controleert tooling en toont de VM-setup.
Installeer wat ontbreekt:

```bash
brew install kubectl helm bind        # 'bind' levert het commando dig
brew install --cask utm
brew install cdrtools                  # optioneel; hdiutil kan ook ISO's maken
```

Zorg voor een SSH-sleutel op de Mac (indien je die nog niet hebt):

```bash
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
```

## 1. Cloud-init aanpassen + seed bouwen

Open `vm/cloud-init/user-data` en:

- plak je publieke sleutel bij `ssh_authorized_keys`;
- controleer `addresses` (`192.168.124.51/24`), `via` (gateway) en de NIC-naam
  `enp0s1`. Wijkt je netwerk af, pas het hier én in `.env` aan.

Bouw de seed-ISO:

```bash
make seed        # levert vm/seed.iso
```

## 2. VM aanmaken in UTM (eenmalig)

1. Download de **Ubuntu 24.04 LTS Server – arm64 cloud image** (`.img`) van
   `https://cloud-images.ubuntu.com/releases/24.04/release/`.
2. UTM → **Create a New Virtual Machine** → **Virtualize** → **Linux**.
3. Zet **Use Apple Virtualization** aan (snelst op M4). Kies het cloud image
   als opstart-disk.
4. Resources: **4 CPU / 8 GB RAM / 60 GB disk**.
5. Ná het aanmaken → **Edit** de VM:
   - **Network** → Mode = **Bridged (Advanced)**, Interface = je bekabelde
     poort (meestal `en0`).
   - **Drives** → **New Drive** → **Import** → kies `vm/seed.iso` (dit is de
     cloud-init bron). Zorg dat dit als extra CD/USB-drive hangt.
6. Hernoem de VM naar **`k3s-server`** (belangrijk: de `make`-targets gebruiken
   die naam via `utmctl`).
7. **Start** de VM.

Cloud-init draait automatisch: gebruiker `ubuntu`, statisch IP `192.168.124.51`,
en k3s wordt geïnstalleerd. Dit duurt enkele minuten.

Wacht tot SSH werkt:

```bash
ssh ubuntu@192.168.124.51 'sudo k3s kubectl get nodes'
```

> Krijg je geen verbinding? Log in via het UTM-console-venster en check met
> `ip a` de NIC-naam en het IP. Zie docs/troubleshooting.md.

## 3. Cluster uitrollen

```bash
make up      # = kubeconfig + bootstrap + verify
```

Dit haalt de kubeconfig op, installeert MetalLB → Traefik → Portainer →
Technitium, en controleert elke laag.

## 4. Direct na de uitrol

1. **Portainer**: open `http://192.168.124.62:9000` en zet **binnen enkele
   minuten** een admin-wachtwoord (anders vergrendelt Portainer zichzelf).
2. **Technitium**: open `http://192.168.124.61:5380`, log in met `admin` en het
   wachtwoord uit je `.env`. Maak een primaire zone `home.brightcubes.nl` met
   A-records `traefik`, `portainer`, `dns` → `192.168.124.60`
   (zie docs/networking.md).
3. Zet de **DNS van je router** (of per apparaat) op `192.168.124.61`.
4. Test: `dig @192.168.124.61 portainer.home.brightcubes.nl +short` → `.60`,
   en open `http://portainer.home.brightcubes.nl`.

## 5. Overleeft een reboot

```bash
make install-autostart
```

Of zet in UTM handmatig **"Start on boot"** aan voor de VM. Overweeg macOS
auto-login zodat de VM zonder handmatige login opstart. k3s zelf herstart
automatisch via systemd zodra de VM draait.

## Dagelijks gebruik

```bash
make verify        # snelle health-check
make vm-down       # VM stoppen
make bootstrap     # config opnieuw toepassen (idempotent)
make uninstall     # cluster-resources verwijderen (VM blijft)
```
