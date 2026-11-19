# agentic-ai

Personal Claude Code configuration: skills, commands, settings, plugins and user-level `CLAUDE.md`, installed into `~/.claude/` by `make install`.

## Setup

```bash
make install           # link claude/* into ~/.claude/, generate settings.json, install plugins
make install-dry-run   # show planned actions and conflicts, change nothing
make install-force     # overwrite a drifted ~/.claude/settings.json (keeps a .bak)
make list-all          # list skills, commands, agents and plugins across scopes; exit 1 on broken links
```

No build step. Requires `jq`; `git`, `bc`, `gh` and `claude` are checked and warned about. New-machine steps are in `README.md`.

## Architecture

```
claude/
├── settings.json                 # Shared Claude Code config, incl. enabledPlugins and their marketplaces
├── settings.local.json           # Gitignored; this machine's overrides
├── settings.local.template.json  # Starter for settings.local.json
├── statusline-command.sh         # Status bar: parses harness JSON, renders 3-line display
├── CLAUDE.md                     # User-level instructions (~/.claude/CLAUDE.md)
├── commands/                     # Slash commands (e.g. /todo)
└── skills/                       # Skills (e.g. projects: cross-repo context)
scripts/
├── install.sh                    # Backs the install targets
└── list_all.sh                   # Backs list-all
```

**Skills** (`skills/*/SKILL.md`) are workflows or context, loaded when their `description` matches or invoked as `/<name>`.

**Commands** (`commands/*.md`) are prompts run as `/<name>`. `disable-model-invocation: true` makes one user-invoked only.

**settings.json** is generated: `install.sh` merges `claude/settings.json` with `claude/settings.local.json` and refuses to overwrite a live file that has drifted. Everything else is symlinked.

**Plugins** are declared, not vendored: `install.sh` adds each `extraKnownMarketplaces` entry and installs each `enabledPlugins` entry missing at user scope.

## Key Conventions

- Edits to skills, commands, `statusline-command.sh` and `CLAUDE.md` are live immediately; edits to either settings file need `make install`.
- Machine- or network-specific values (gateway URL, local hook paths, `autoMode` context) go in `settings.local.json`, never the shared `settings.json`.
- A plugin from a marketplace other than the built-in directory needs its marketplace in `extraKnownMarketplaces`, or fresh installs can't resolve it.
- `allowed-tools` only when a skill needs to pre-approve tools; keep it minimal.
- GitHub operations use the `gh` CLI.
