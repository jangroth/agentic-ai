# agentic-ai

Personal [Claude Code](https://claude.ai/code) configuration — version-controlled skills, commands, and settings symlinked into `~/.claude/`.

## Install

```bash
make install
```

Requires `jq`. Warns if `git`, `bc` (status line), `gh` (`/todo`) or `claude` (plugins) is missing.

Besides linking and generating settings, `make install` adds the marketplaces in `extraKnownMarketplaces` and installs every plugin in `enabledPlugins` at user scope. Re-running it is safe.

### New machine

1. Install the Claude Code CLI, `jq`, `gh` and `bc`.
2. Create `claude/settings.local.json` (see [Machine-specific settings](#machine-specific-settings)), so the first run already has this machine's gateway URL.
3. Run `make install` **before starting Claude Code**. Claude Code writes its own `~/.claude/settings.json` on first run, which the installer then refuses to overwrite. If that has already happened, use `make install-force` (keeps a `.bak`).

## Structure

```
claude/
├── settings.json               # Shared Claude Code config (status line, hooks, plugins, etc.)
├── settings.local.template.json  # Reference/starter for machine-specific overrides
├── settings.local.json         # Gitignored — this machine's overrides (not tracked)
├── statusline-command.sh       # Terminal status bar: model, context, git, cost, agents
├── CLAUDE.md                   # User-level instructions for all projects (~/.claude/CLAUDE.md)
├── commands/                   # Custom slash commands (e.g. /todo)
└── skills/                     # Skills (e.g. projects: cross-repo context)
```

Skills, commands, `statusline-command.sh`, and `CLAUDE.md` are symlinked, so edits take effect immediately.

`settings.json` is different: `~/.claude/settings.json` is *generated* by merging `claude/settings.json` (shared, committed) with `claude/settings.local.json` (machine-specific, gitignored) via `jq`, so it can't just be symlinked. **Re-run `make install` after editing either file.**

### Machine-specific settings

Values that depend on this machine/network — a custom `ANTHROPIC_BASE_URL`, an MCP server pointing at a private host, or a hook command referencing a path/plugin only installed on this machine (e.g. `~/.claude/hooks/some-plugin-hook.mjs`) — don't belong in the shared `settings.json`. Instead:

1. Copy the template: `cp claude/settings.local.template.json claude/settings.local.json`
2. Edit `claude/settings.local.json` for this machine — it's gitignored and merged on top of the shared config by `make install`.
3. Update `claude/settings.local.template.json` (tracked) if the defaults worth starting from on a new machine change.

If `claude/settings.local.json` doesn't exist, `make install` just uses the shared `settings.json` as-is.

### Safety: never overwriting unintegrated changes

`scripts/install.sh` never silently clobbers something that hasn't made it into this repo yet:

- **Skills/commands/statusline**: if a destination under `~/.claude/` is a real file or directory (not a symlink this script manages), it's reported as `[CONFLICT]` and left untouched. Move or fold the content into this repo, then re-run.
- **`settings.json`**: before writing, the script diffs the live `~/.claude/settings.json` against what `claude/settings.json` + `claude/settings.local.json` would produce. If they differ — e.g. a plugin installer added a key directly to the live file — it prints the diff and refuses to overwrite. Copy the new bits into the repo (or `settings.local.json`), then re-run. `make install-force` overwrites anyway (a `.bak` is still kept).

Run `make install-dry-run` to see the full plan — conflicts, settings.json drift and diff — with no prompt and no changes made. It exits non-zero if anything would be left untouched, so it's safe to script/check.
