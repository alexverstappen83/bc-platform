# Interne DNS (brightcubes.ai) — runbook

Interne DNS via **Technitium** zodat je apps op hun hostnaam werken
(`bcdoelen.ontwikkel.brightcubes.ai`). Domein = `brightcubes.ai` (split-horizon;
e-mail draait op brightcubes.**nl**, dus de apex is veilig intern te gebruiken).

> **NAT nu (tijdelijk):** Technitium en Traefik zitten in de VM en zijn alleen
> vanaf de Mac Mini bereikbaar. We forwarden ze naar het LAN via de Mac Mini. Met
> de **UTP-kabel + `NETWORK_MODE=bridged`** krijgen ze een eigen LAN-IP en
> vervallen alle forwards (en wordt echte TLS mogelijk).

## 1. Forwards op de Mac Mini
```bash
make lan-forward          # DNS op :5354 (geen sudo)
sudo make lan-forward     # idem + HTTP op :80 (sudo, privileged poort)
```
- **Poort 80 al bezet?** Vaak een oude **Lima-VM**. Check + stop:
  ```bash
  sudo lsof -nP -iTCP:80 -sTCP:LISTEN
  limactl stop <naam>     # of: limactl delete <naam>
  ```
  De socat-lus pakt poort 80 daarna vanzelf.

## 2. Zone + records in Technitium (via de API)
De web-UI (5380) is een ClusterIP-service; tunnel er even naartoe:
```bash
export KUBECONFIG=~/bc-platform/kubeconfig
kubectl -n technitium port-forward svc/technitium-web 5380:5380 >/dev/null 2>&1 &
PF=$!; sleep 3
T="http://127.0.0.1:5380"
TOKEN=$(curl -s "$T/api/user/login?user=admin&pass=changeme" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
curl -s "$T/api/zones/create?token=$TOKEN&zone=brightcubes.ai&type=Primary"; echo
curl -s "$T/api/zones/records/add?token=$TOKEN&domain=bcdoelen.ontwikkel.brightcubes.ai&type=A&ipAddress=<MAC-MINI-LAN-IP>&ttl=300"; echo
kill $PF 2>/dev/null
```
Vervang `<MAC-MINI-LAN-IP>` door het echte LAN-IP van de Mac Mini
(`ipconfig getifaddr en1`, bijv. `192.168.124.25`). Nieuwe apps = extra A-record.

## 3. Clients naar Technitium (per Mac, veilig gescoped)
Alleen `brightcubes.ai`-queries gaan naar Technitium (poort 5354); de rest van je
internet blijft ongemoeid:
```bash
sudo mkdir -p /etc/resolver
printf "nameserver <MAC-MINI-LAN-IP>\nport 5354\n" | sudo tee /etc/resolver/brightcubes.ai
sudo killall -HUP mDNSResponder
```

## 4. Test
```bash
ping -c1 bcdoelen.ontwikkel.brightcubes.ai      # -> Mac-Mini-IP
# browser: http://bcdoelen.ontwikkel.brightcubes.ai
```

## Aandachtspunten
- **Reboot:** de forwards zijn achtergrondprocessen; na herstart opnieuw
  `sudo make lan-forward`. (Duurzaam maken kan later met een launchd-agent.)
- **DHCP:** geef de Mac Mini een vast IP in je router (AmpliFi), anders verspringt
  het `.25`-adres en kloppen de DNS-records niet meer.
- **Mac Mini's eigen poort 53** is van `mDNSResponder` (macOS) — daarom draait de
  DNS-forward op 5354.
