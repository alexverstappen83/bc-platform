# Applicaties (DTAP via GitOps)

Elke app krijgt een eigen map met een **Kustomize base** + **overlays per omgeving**.
ArgoCD (ApplicationSet) pikt elke `apps/<app>/overlays/<omgeving>` automatisch op en
rolt 'm uit in de bijbehorende namespace (`ontwikkel` / `test-acceptatie` /
`productie`).

## Structuur
```
apps/<app>/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
└── overlays/
    ├── ontwikkel/kustomization.yaml
    ├── test-acceptatie/kustomization.yaml
    └── productie/kustomization.yaml
```

## Een nieuwe app toevoegen
1. Kopieer een bestaande app-map (of vraag mij 'm te genereren).
2. Zet in `base/` het image, de poort en de ingress-host.
3. Zet per overlay de namespace, replicas en (later) de image-tag.
4. Commit → ArgoCD maakt automatisch de Applications aan (prod = handmatige sync).

## Voorbeeld — base
`base/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: APPNAME }
spec:
  selector: { matchLabels: { app: APPNAME } }
  template:
    metadata: { labels: { app: APPNAME } }
    spec:
      containers:
        - name: APPNAME
          image: ghcr.io/OWNER/APPNAME:latest   # tag wordt per overlay/CI gezet
          ports: [ { containerPort: PORT } ]
```
`base/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata: { name: APPNAME }
spec:
  selector: { app: APPNAME }
  ports: [ { port: 80, targetPort: PORT } ]
```
`base/ingress.yaml` (host krijgt per overlay een prefix):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: { name: APPNAME }
spec:
  ingressClassName: traefik
  rules:
    - host: APPNAME.OMGEVING.DOMEIN     # via overlay-patch ingevuld
      http:
        paths:
          - { path: /, pathType: Prefix, backend: { service: { name: APPNAME, port: { number: 80 } } } }
```
`base/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [ deployment.yaml, service.yaml, ingress.yaml ]
```

## Voorbeeld — overlay (ontwikkel)
`overlays/ontwikkel/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ontwikkel
resources: [ ../../base ]
images:
  - name: ghcr.io/OWNER/APPNAME
    newTag: latest          # CI zet hier de git-sha van de laatste build
replicas:
  - { name: APPNAME, count: 1 }
# host per omgeving zetten (bijv. via patch of replacements)
```

> `test-acceptatie` en `productie` zijn identiek, met andere `namespace`, `newTag`
> (vaste release i.p.v. latest) en hogere `replicas` in productie.
