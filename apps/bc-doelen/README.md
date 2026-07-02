# BC-Doelen op k3s (DTAP via ArgoCD)

Vertaling van de `docker-compose.yml` van
[BC-Doelen](https://github.com/alexverstappen83/BC-Doelen) naar Kubernetes.

## Compose → Kubernetes
| Compose | Kubernetes | Opmerking |
|---|---|---|
| db (postgres:16) | `db.yaml`: Deployment + PVC + Service | eigen DB per omgeving |
| api (`./backend`, `api`) | `api.yaml`: Deployment + Service (:8000) | image via CI → ghcr |
| worker (`./backend`, `worker`) | `worker.yaml`: Deployment (zelfde image) | `args: [worker]` |
| frontend (`./frontend`) | `frontend.yaml`: Deployment + Service (:80) | image via CI → ghcr |
| proxy (Caddy) | `ingress.yaml`: Traefik-Ingress | routing 1-op-1 uit de Caddyfile |
| backup | **TODO: CronJob** (pg_dump) | volgt |
| updater | **geschrapt** | ArgoCD/CI doen de updates |

> **Updater weg:** de app-feature die de compose-stack zelf bijwerkt is in k8s
> overbodig. `UPDATER_URL` is niet gezet; als de backend die functie hard nodig
> heeft, meld het — dan lossen we dat apart op.

## Images (CI bouwt & pusht naar ghcr)
- `ghcr.io/alexverstappen83/bc-doelen-backend` (uit `./backend`) — voor api én worker.
- `ghcr.io/alexverstappen83/bc-doelen-frontend` (uit `./frontend`).

## Secret aanmaken (out-of-band, niet in Git)
Per omgeving één keer. Genereert sterke waarden voor ontwikkel:
```bash
export KUBECONFIG=~/bc-platform/kubeconfig
PGPW="$(openssl rand -hex 16)"
kubectl -n ontwikkel create secret generic bc-doelen-secrets \
  --from-literal=POSTGRES_PASSWORD="$PGPW" \
  --from-literal=DATABASE_URL="postgresql+psycopg://bcdoelen:${PGPW}@db:5432/bcdoelen" \
  --from-literal=JWT_SECRET="$(openssl rand -hex 32)" \
  --from-literal=SECRET_ENCRYPTION_KEY="$(openssl rand -base64 32)" \
  --from-literal=INITIAL_ADMIN_PASSWORD="VeranderMij12tekens" \
  --from-literal=GITHUB_TOKEN="" \
  --dry-run=client -o yaml | kubectl apply -f -
```
> **Let op `SECRET_ENCRYPTION_KEY`:** als de backend een specifiek formaat
> verwacht (bijv. een Fernet-key), pas de generatie daarop aan. Twijfel? Geef het
> formaat door.

## Uitrollen
ArgoCD pikt `overlays/ontwikkel` automatisch op (ApplicationSet `bc-apps-auto`).
Handmatig testen zonder ArgoCD kan met:
```bash
kubectl apply -k apps/bc-doelen/overlays/ontwikkel
kubectl -n ontwikkel get pods
```

## Bereikbaarheid (NAT nu)
De ingress-host `bcdoelen.ontwikkel.brightcubes.ai` werkt LAN-breed pas met DNS +
bridged. Voor nu testen via port-forward of met een Host-header:
```bash
kubectl -n ontwikkel port-forward svc/frontend 8081:80   # SPA
kubectl -n ontwikkel port-forward svc/api 8000:8000       # API /health
```

## test-acceptatie / productie
Kopieer `overlays/ontwikkel` → `overlays/test-acceptatie` en `overlays/productie`,
pas `namespace`, host, `newTag` (vaste release i.p.v. latest) en replicas aan, en
maak het `bc-doelen-secrets`-Secret in die namespaces.
