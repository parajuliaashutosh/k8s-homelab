# k8s-homelab

GitOps-managed homelab Kubernetes manifests using Flux and Kustomize.

## Structure

- `clusters/homelab/` Flux Kustomizations that reconcile the repo.
  - `apps.yaml` applies everything in `./apps`.
  - `infrastructure.yaml` applies everything in `./infrastructure`.
- `apps/` each app runs in its own namespace (`auth-proxy`, `portfolio`, `money-order`).
  - `auth-proxy/backend` auth service, also used by Traefik forwardAuth.
  - `portfolio/frontend`, `portfolio/chatbot` portfolio frontend and chatbot.
  - `money-order/backend` money-order API, worker and migration job.
- `infrastructure/`
  - `cloudflared` Cloudflare Tunnel for public routing.
  - `zot` container registry with UI and basic auth.

## Apps

### Portfolio frontend

- Deployment `portfolio` runs `registry.aashutoshparajuli.com.np/portfolio/frontend:0.0.4` on port 3000.
- Service `portfolio-frontend` exposes port 80 -> 3000.
- Ingress host: `portfolio.local`.
- Runs in the `portfolio` namespace. Registry auth is node-level (see below).

### Zot registry

- Runs in the `registry` namespace. Deployment `zot` on port 5000, images stored on the `zot-pvc` (local-path) PVC.
- Service `zot` exposes port 5000 in the cluster and NodePort 32630 on the node (used for local pushes, bypassing Cloudflare).
- Ingress host: `registry.local`.
- Users live in the SOPS-encrypted `zot-htpasswd` secret (`infrastructure/zot/secret.yaml`, bcrypt htpasswd lines):
  - `_admin` full access via `adminPolicy`.
  - `pushuser` read/create/update (local pushes, can overwrite tags).
  - `ci-push` read/create (CI robot, can push new tags but not overwrite or delete).
  - `pulluser` read only (k3s nodes via `registries.yaml`).

### Cloudflared

- Deployment `cloudflared` with config from `cloudflared-config`.
- Routes:
  - `aashutoshparajuli.com.np` -> `portfolio-frontend.default.svc.cluster.local:80`
  - `registry.aashutoshparajuli.com.np` -> `zot.registry.svc.cluster.local:5000`
- Uses `tunnel-credentials` secret.

## Prerequisites

- A Flux installation in the `flux-system` namespace.
- Secrets present in `default` namespace:
  - `tunnel-credentials` for Cloudflare Tunnel.

### Secret setup

Create the required secrets in the `default` namespace:

```bash
kubectl -n default create secret generic tunnel-credentials \
  --from-file=credentials.json=/path/to/credentials.json
```

To add or change a zot user, generate a bcrypt line and put it in `infrastructure/zot/secret.yaml` with `sops edit`:

```bash
htpasswd -nbB <user> <password>
```

### Registry pull auth

Apps don't use `imagePullSecrets`. Each k3s node logs in to zot itself via
`/etc/rancher/k3s/registries.yaml` using the read-only `pulluser`:

```yaml
configs:
  "registry.aashutoshparajuli.com.np":
    auth:
      username: pulluser
      password: YOUR_PASSWORD
```

Then restart k3s: `sudo systemctl restart k3s` (or `k3s-agent` on agent nodes).

## Apply

Flux reconciles automatically based on the Kustomizations in `clusters/homelab/`.

If you need to reconcile manually, run:

```bash
flux reconcile kustomization apps -n flux-system
flux reconcile kustomization infrastructure -n flux-system
```

## Local access

- Add DNS or /etc/hosts entries for `portfolio.local` and `registry.local` pointing to your cluster ingress.

## Traffic flow

```mermaid
flowchart LR
  internet[Internet] --> cf[Cloudflare Tunnel]
  cf -->|aashutoshparajuli.com.np| pfsvc[portfolio-frontend svc]
  cf -->|registry.aashutoshparajuli.com.np| zotsvc[zot svc]

  pfsvc --> pfpod[portfolio pod]
  zotsvc --> zotpod[zot pod]

  local[Local DNS / hosts] -->|portfolio.local| pfsvc
  local -->|registry.local| zotsvc
```
