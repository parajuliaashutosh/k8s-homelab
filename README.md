# k8s-homelab

My homelab, managed with GitOps.

## Setup

- **Proxmox**: one node, the hypervisor everything runs on.
- **Ubuntu VM** with **k3s**: a single-node Kubernetes cluster.
- **Flux** syncs the cluster from this repo. Secrets are encrypted with **SOPS + age**.

## Repo layout

| Folder | What it is |
|---|---|
| [`k8s/`](k8s/README.md) | Kubernetes manifests reconciled by Flux (apps, infrastructure, self-hosted) |
| [`images/`](images/) | Custom container images (e.g. `pgbackup` for Postgres backups) |
| [`scripts/audit/`](scripts/audit/README.md) | Lynis security audit of the host |

## Further reading

- [`k8s/README.md`](k8s/README.md): apps, registry, tunnel and secret setup
- [`k8s/CHEATSHEET.md`](k8s/CHEATSHEET.md): everyday kubectl / flux commands and debugging
- [`scripts/audit/README.md`](scripts/audit/README.md): running the security audit
