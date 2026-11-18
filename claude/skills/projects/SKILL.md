---
name: projects
description: Context across the user's repos — homekube (+ homekube-main/-apps), homekube-bakery, herminator, herminator-state, ai-gateway, dotfiles, agentic-ai. Use when work touches one of them from another directory, or a change in one affects another — e.g. deploying an app to the Pi cluster, building an image for it, changing the tailnet/gateway policy, editing shell/editor/terminal config, or changing Claude Code config.
---
# Projects

Each repo's own `CLAUDE.md` is the source of truth for working in it: branching, planning, records, labels. Read it before editing a repo you aren't in: it isn't loaded when the cwd is elsewhere.

## Repos

| Repo | Path | Visibility | Purpose | Issues |
|---|---|---|---|---|
| `homekube` | `~/Projects/kube/homekube` | public | Kubernetes on 4x Raspberry Pi 5: specs, decisions, changelog | `jangroth/homekube`, shared by all three |
| `homekube-main` | `~/Projects/kube/homekube/homekube-main` | public | Ansible provisioning, k8s install, ArgoCD bootstrap | → `jangroth/homekube`, label `repo:homekube-main` |
| `homekube-apps` | `~/Projects/kube/homekube/homekube-apps` | public | ArgoCD Applications (App-of-Apps), watched by the cluster | → `jangroth/homekube`, label `repo:homekube-apps` |
| `homekube-bakery` | `~/Projects/homekube-bakery` | public | Builds and publishes every image homekube runs (GHCR, `linux/arm64`) | own repo |
| `herminator` | `~/Projects/herminator` | public | Helm chart for Hermes Agent on homekube | own repo |
| `herminator-state` | not cloned; `gh … -R jangroth/herminator-state` | **private** | Hermes' runtime state (config, `SOUL.md`, memories, cron, skills, scripts), exported hourly by herminator | none; file against herminator |
| `ai-gateway` | `~/Projects/ai-gateway` | **private** | Tailnet policy for the Aperture gateway `ai` (this machine's `ANTHROPIC_BASE_URL`) | own repo |
| `dotfiles` | `~/Projects/dotfiles` | public | Shell, editor, git, tmux, terminal config for macOS/Linux | own repo |
| `agentic-ai` | `~/Projects/agentic-ai` | public | Claude Code config: skills, commands, settings, `~/.claude/CLAUDE.md` | own repo |

`homekube-main` and `homekube-apps` are separate git repos nested inside `homekube` (gitignored there).

Content from `ai-gateway` (hostnames, grants, credentials setup) and `herminator-state` (Hermes' memories, persona, config) never goes into a public repo.

## How they connect

- **Images**: homekube builds no images. Bakery publishes them; consumers pin by tag and digest with a `# renovate:` comment. What an image guarantees is in bakery's `CONTRACT.md`. Request image changes as bakery issues. A major tag bump means the contract broke: review by hand.
- **Hermes**: herminator owns the chart (`chart/`) and consumes bakery's Hermes image. `homekube-apps` owns the thin ArgoCD `Application` and Dex `staticClients` wiring. A material change on the homekube-apps side is logged in both repos' `DECISIONS.md`/`CHANGELOG.md`.
- **Hermes state**: `herminator-state` is generated; every commit comes from the hourly export, and manual edits are overwritten. Read it to see what Hermes is actually running. Change what gets exported in `stateExport` in herminator's `chart/values.yaml`, and change Hermes itself through herminator or the running instance.
- **New app on the cluster**: add an Application manifest to `homekube-apps` (wave folder + `applications/kustomization.yaml`), then commit and push; ArgoCD syncs. Wave layout and sync rules: `homekube-apps/CLAUDE.md`.
- **Gateway**: merging `policy.hujson` to `main` in `ai-gateway` applies it to the live tailnet. Access changes there can break Claude Code on this machine.
- **Claude config**: `agentic-ai` symlinks skills, commands, statusline and `CLAUDE.md` into `~/.claude/`; `settings.json` is generated, so re-run `make install` after editing it.
