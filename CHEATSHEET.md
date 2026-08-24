# K3s Homelab Cheatsheet

## Pod & Deployment Commands

```bash
# Get pods with label selector
kubectl get pods -l app=<name>

# Watch pods in real time
kubectl get pods -l app=<name> -w

# Get logs
kubectl logs -l app=<name> --tail=30

# Restart a deployment
kubectl rollout restart deployment/<name>

# Describe pod (events, mounts, errors)
kubectl describe pod -l app=<name>

# Exec into pod
kubectl exec -it <pod-name> -- sh

# Check env vars in pod
kubectl exec -it <pod-name> -- env | grep <KEY>

# Force delete stuck pod
kubectl delete pod -l app=<name> --force --grace-period=0

# Check what image a deployment is using
kubectl get deployment <name> -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Flux Commands

```bash
# Check all kustomizations
flux get kustomizations

# Force sync from GitHub
flux reconcile source git flux-system
flux reconcile kustomization apps
flux reconcile kustomization infrastructure

# Check what Flux has applied (inventory)
kubectl get kustomization apps -n flux-system -o yaml | grep -A30 "inventory"

# Check Flux errors
kubectl describe kustomization apps -n flux-system | grep -A10 "Message"
kubectl describe kustomization infrastructure -n flux-system | grep -A10 "Message"
```

---

## K3s Image Management

```bash
# Import Docker image into K3s containerd
docker save <image>:<tag> | sudo k3s ctr images import -

# List images in K3s
sudo k3s ctr images list | grep <name>

# Remove image from K3s
sudo k3s ctr images rm docker.io/library/<image>:<tag>
```

---

## Secrets

```bash
# Create secret from literals
kubectl create secret generic <name> \
  --from-literal=KEY=value \
  --namespace default

# Create docker registry secret
kubectl create secret docker-registry <name> \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass> \
  --namespace default

# View secret value (base64 decoded)
kubectl get secret <name> -o jsonpath='{.data.<KEY>}' | base64 -d

# Update existing secret (dry-run patch)
kubectl create secret generic <name> \
  --from-literal=KEY=value \
  --dry-run=client -o yaml | kubectl apply -f -

# List all secrets
kubectl get secrets -n default
kubectl get secrets -n flux-system
```

---

## SOPS + Age

```bash
# Generate Age key pair
age-keygen -o age.agekey

# Encrypt a secret file in place
sops --encrypt --in-place secret.yaml

# Decrypt to view (never commit decrypted)
sops --decrypt secret.yaml

# Store Age private key in cluster for Flux
kubectl create secret generic sops-age \
  --from-file=age.agekey=$HOME/age.agekey \
  --namespace flux-system
```

`.sops.yaml` config:

```yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    age: age1yourpublickeyhere
```

---

## Ingress & Middleware

```bash
# List all ingresses
kubectl get ingress -A

# Check middleware
kubectl get middleware -n default

# Describe middleware
kubectl describe middleware <name> -n default

# Test ingress routing locally (bypass Cloudflare)
curl -I -H "Host: yourdomain.com" http://<VM_IP>

# Test through Cloudflare
curl -I https://yourdomain.com
```

---

## Cloudflare Tunnel

```bash
# Add DNS route for a subdomain
cloudflared tunnel route dns k8s-homelab subdomain.yourdomain.com

# Check tunnel config in cluster
kubectl get configmap cloudflared-config -o yaml | grep hostname

# Restart cloudflared after config change
kubectl rollout restart deployment/cloudflared

# Watch cloudflared logs for routing issues
kubectl logs -l app=cloudflared -f
```

**Key log fields to look for:**

- `originService=` — shows where cloudflared is routing to
- `ingressRule=` — which rule matched
- `ERR Request failed` — connection issues

---

## Debugging Strategies

### Pod stuck in ContainerCreating

```bash
kubectl describe pod -l app=<name> | grep -A10 "Events"
```

**Common causes:**

- `MountVolume.SetUp failed` → ConfigMap or Secret referenced in volume doesn't exist
- `failed to pull image` → image tag wrong or registry unreachable
- `ImagePullBackOff` → wrong image name, tag, or missing imagePullSecret

---

### Pod in CrashLoopBackOff

```bash
kubectl logs -l app=<name> --tail=30
kubectl logs -l app=<name> --previous  # logs from crashed container
```

**Common causes:**

- Missing env vars → add `envFrom` or `env` in deployment
- Wrong config file path → check volumeMounts and configmap keys
- YAML indentation error in configmap → pod reads corrupted config
- Alpine vs glibc issue → native Node addons need `node:slim` not `node:alpine`

---

### Flux not applying changes

1. Check if file is committed and pushed to GitHub
2. Check if file is listed in `kustomization.yaml` resources
3. Force reconcile: `flux reconcile source git flux-system`
4. Check for YAML errors: `kubectl describe kustomization <name> -n flux-system`

**Common causes:**

- File not in `kustomization.yaml` resources list
- YAML syntax error → check indentation, no tabs
- Wrong filename in resources (e.g. `config.yaml` vs `configmap.yaml`)

---

### ConfigMap change not picked up by pod

ConfigMap updates don't restart pods automatically. Always run:

```bash
kubectl rollout restart deployment/<name>
```

---

### 502 Bad Gateway

```bash
# Test if pod is responding
curl -I -H "Host: <hostname>" http://<VM_IP>

# Check if service selector matches pod labels
kubectl describe svc <name>
kubectl get pods --show-labels
```

**Common causes:**

- Pod not running or not ready
- Service selector doesn't match pod labels
- Wrong targetPort in service
- App still initializing (pgadmin takes 2-3 min on first boot)

---

### 404 Not Found from Traefik

**Common causes:**

- Ingress host doesn't match request hostname
- Middleware referenced in ingress annotation doesn't exist yet
- Ingress missing `paths` array under a host rule

---

### 413 Payload Too Large

- Cloudflare has 100MB limit on free plan for request body
- For registry pushes: use NodePort to bypass Cloudflare
- Add `originRequest` timeouts in cloudflared configmap for large uploads

---

### Headers not being stripped

Check if traffic is going through Traefik:

```bash
kubectl logs -l app=cloudflared --tail=10 | grep originService
```

If `originService` points directly to a service (not Traefik), Traefik middleware is bypassed.
**Fix:** Point cloudflared to `http://traefik.kube-system.svc.cluster.local:80`

---

### SOPS secret not created by Flux

1. Check secret.yaml is in `kustomization.yaml` resources
2. Check Flux has decryption config in `clusters/homelab/apps.yaml`
3. Check `sops-age` secret exists in `flux-system` namespace
4. Check `encrypted_regex` in `.sops.yaml` matches `^(data|stringData)$`

---

## Service DNS Names (inside cluster)

```
postgres:   postgres.default.svc.cluster.local:5432
redis:      redis.default.svc.cluster.local:6379
temporal:   temporal.default.svc.cluster.local:7233
zot:        zot.default.svc.cluster.local:5000
traefik:    traefik.kube-system.svc.cluster.local:80
```

---

## Storage Paths on VM

```
/var/lib/infrastructure/postgres    → Postgres data
/var/lib/infrastructure/redis       → Redis data
/var/lib/infrastructure/registry    → Zot registry images
```

---

## Folder Structure

```
~/k8s/
  apps/
    portfolio/frontend/
    money-order/backend/
  infrastructure/
    cloudflared/
    zot/
    postgres/
      core/
      pgadmin/
    redis/
    temporal/
      core/
      ui/
  clusters/
    homelab/
      flux-system/
      apps.yaml
      infrastructure.yaml
  .sops.yaml
```

---

## Quick Health Check

```bash
kubectl get pods -A | grep -v Running | grep -v Completed
flux get kustomizations
kubectl get ingress -A
flux get source git
```
