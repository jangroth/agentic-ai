# agentic-ai

Personal Claude Code configuration: skills, commands, settings, plugins and user-level `CLAUDE.md`, installed into `~/.claude/` by `make install`.

## Setup

```bash
make install           # link claude/* into ~/.claude/, generate settings.json, install plugins
make install-dry-run   # show planned actions and conflicts, change nothing
make install-force     # overwrite a drifted ~/.claude/settings.json (keeps a .bak)
```

`make help` lists the rest. Setting up a new machine → `README.md`.

## Live files

Skills, commands, `statusline-command.sh` and `CLAUDE.md` are symlinked, so edits are live immediately. `claude/CLAUDE.md` is `~/.claude/CLAUDE.md`: editing it changes every project.

## Settings

`~/.claude/settings.json` is generated: `install.sh` merges `claude/settings.json` with the gitignored `claude/settings.local.json` and refuses to overwrite a live file that has drifted. Run `make install` after editing either.

Machine- or network-specific values (gateway URL, local hook paths, `autoMode` context) go in `settings.local.json`; `settings.json` holds only what every machine shares.

## Plugins

Plugins are declared, not vendored: `install.sh` adds each `extraKnownMarketplaces` entry and installs each `enabledPlugins` entry missing at user scope. A plugin from a marketplace other than the built-in directory needs its marketplace in `extraKnownMarketplaces`, or fresh installs can't resolve it.

## Skills

`allowed-tools` only when a skill needs to pre-approve tools; keep it minimal.
