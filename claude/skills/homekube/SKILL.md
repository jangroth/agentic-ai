---
name: homekube
description: Use when building or deploying an application intended to be hosted on the homekube Raspberry Pi cluster, or referencing the homekube/homekube-main/homekube-apps repos from another directory. Triggers on "homekube", "my pi cluster", "deploy to my cluster", "add an ArgoCD app", "host this on k8s at home". Points to repo layout, ArgoCD app-of-apps conventions, and access details so apps land correctly even when cwd is elsewhere.
---
# Homekube

Vanilla Kubernetes on 4x Raspberry Pi 5, GitOps via ArgoCD (App-of-Apps).

## Repos

| Repo | Path | Purpose |
|------|------|---------|
| `homekube` | `~/Projects/kube/homekube` | Top-level: specs, decisions, changelog, issue tracker |
| `homekube-main` | `~/Projects/kube/homekube/homekube-main` | Ansible provisioning, k8s install, ArgoCD bootstrap |
| `homekube-apps` | `~/Projects/kube/homekube/homekube-apps` | ArgoCD Application manifests (App-of-Apps) |

## Adding a new app to the cluster

This is the entry point for "I built something, now host it on homekube":

1. Create `applications/wave-NN-<wave>/<app-name>.yaml` in `homekube-apps` — an ArgoCD Application manifest
2. Add it to `applications/kustomization.yaml`
3. Set `argocd.argoproj.io/sync-wave: "N"` respecting dependency order:

   | Wave | Contains |
   |------|----------|
   | `wave-00-init` | LB, storage, metrics, cert-manager, DNS — foundation |
   | `wave-01-apps` | Observability (Prometheus/Loki/Alloy), storage extras |
   | `wave-02-apps` | Dex (OIDC) |
   | `wave-03-apps` | Dashboard, general apps — most new apps land here |
4. Commit and push to `homekube-apps` — ArgoCD auto-syncs, no manual `kubectl apply`

## Cluster access

| Node | Role | Tailscale |
|------|------|-----------|
| pi0 | Control plane | `ssh homekube@pi0` (MagicDNS) |
| pi1-3 | Data plane | `ssh homekube@pi{1,2,3}` |

- All access (SSH, kubectl, ansible) goes over Tailscale — works from any network.
- ArgoCD is exposed as a LoadBalancer VIP: `kubectl -n argocd get svc cst-argocd-server`.

## Stack (compatibility-relevant)

Kubernetes (kubeadm) · Cilium (CNI + LB-IPAM/L2, held) · Longhorn (CSI/storage class) · ArgoCD. Versions: `homekube-main/ansible/group_vars/all.yml` and `homekube-apps/applications/**/*.yaml` → `targetRevision`.

## Images

homekube builds no images. Images built for it (Coder workspace, Hermes) come from [`jangroth/homekube-bakery`](https://github.com/jangroth/homekube-bakery), public on GHCR, `linux/arm64`.

- What an image guarantees is in the bakery's `CONTRACT.md`. Request changes as issues on the bakery repo, not on the homekube tracker.
- Pin by tag and digest with a `# renovate:` comment. Tags are immutable semver; a major bump means the contract broke, review by hand.

## Working conventions

Apply these even when the app itself lives in an unrelated repo:

- **Spec first**: significant homekube-facing changes get a spec in `homekube/docs/specs/NNN-title.md` before implementation.
- **Decisions**: recorded in `homekube/DECISIONS.md` (why), newest first.
- **Changes**: recorded in `homekube/CHANGELOG.md` (what), reverse-chronological.
- **Issues**: single tracker — GitHub Issues on `jangroth/homekube`, labelled `area:*`, `criticality:blocker|degraded|polish`, `repo:homekube|homekube-main|homekube-apps`. File app-hosting work there, don't start a separate tracker in the app's own repo.
- **Source reflects runtime**: any change applied directly to the running cluster must be propagated back to the canonical file (Ansible role, Helm values, manifest) in the same piece of work.

For anything not covered here, read the three repos' own `CLAUDE.md` files (root + `homekube-main/` + `homekube-apps/`) — they're the source of truth.
