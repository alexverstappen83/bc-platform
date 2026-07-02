# CI/CD & GitOps (Milestone 2)

Doel: je eigen GitHub-apps automatisch builden en via **ArgoCD** uitrollen naar
`ontwikkel` / `test-acceptatie` / `productie`.

## Flow
```
app-repo (code + Dockerfile)
  --GitHub Actions--> build image --> ghcr.io/<owner>/<app>:<git-sha>
  --schrijft image-tag terug--> bc-platform (apps/<app>/overlays/ontwikkel)
ArgoCD (in cluster) --polt bc-platform--> sync naar de juiste namespace
```
Alles is uitgaand verkeer → werkt achter NAT. Harbor (private registry) en echte
hostnamen/TLS komen in Stage 2 (na DNS-keuze + bekabeld/bridged).

## Eenmalig opzetten
1. **ArgoCD installeren** (op de Mac): `make argocd`. Toont het admin-wachtwoord en
   hoe je de UI opent (port-forward, net als Portainer).
2. **ArgoCD toegang tot deze repo** (nodig als bc-platform *private* is): voeg de
   repo toe met een read-only credential. Twee opties:
   - UI: Settings → Repositories → Connect repo (HTTPS) → PAT met `repo:read`.
   - CLI: `argocd repo add https://github.com/alexverstappen83/bc-platform.git --username <user> --password <PAT>`.
   Zonder dit kan de ApplicationSet de `apps/*`-mappen niet lezen.
3. **CI in je app-repo**: kopieer `docs/ci-templates/build.yaml` naar
   `.github/workflows/build.yaml` in je app-repo en vul de placeholders in
   (`OWNER`, `APPNAME`). Zet in die repo één secret:
   - `BC_PLATFORM_PAT` — fijnmazige PAT met **write** op alléén `bc-platform`
     (Contents: read/write). Wordt gebruikt om de nieuwe image-tag terug te
     schrijven naar de overlay.
4. **ghcr-image publiek of privé?**
   - **Publiek** (simpelst): cluster pullt zonder inloggegevens. Zet het package na
     de eerste push op public in GitHub.
   - **Privé**: maak per namespace een `imagePullSecret` (ghcr-PAT met
     `read:packages`) en verwijs ernaar in de deployment.

## Promotiemodel (DTAP)
- `ontwikkel` — **automatisch**: elke push naar `main` bouwt en deployt.
- `test-acceptatie` — promoveer een specifieke tag (PR die de overlay-tag bijwerkt),
  ArgoCD synct automatisch.
- `productie` — **handmatige** goedkeuring: sync-knop in de ArgoCD-UI, met een vaste
  release-tag (nooit `latest`).

## Een app aanhaken (wat ik voor je doe)
Zodra je me geeft: **repo-URL + Dockerfile-pad + poort + ghcr-owner + publiek/privé**,
genereer ik `apps/<app>/base` + de drie overlays en commit ik ze in bc-platform.
ArgoCD maakt dan automatisch de Applications aan.
