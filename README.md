# agentic-ai

Personal [Claude Code](https://claude.ai/code) configuration — version-controlled skills, commands, and settings symlinked into `~/.claude/`.

## Install

```bash
make install
```

Requires: `bash`, `jq`, `git`, `gh`, `bc`.

## Structure

```
claude/
├── settings.json            # Claude Code config (status line, permissions, etc.)
├── statusline-command.sh    # Terminal status bar: model, context, git, cost, agents
├── commands/                # Custom slash commands (e.g. /todo)
└── skills/                  # Reusable workflow skills (e.g. /pr)
```

Edits take effect immediately — no need to re-run `make install` after the initial setup.
