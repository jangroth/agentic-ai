# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal Claude Code configuration repository. It version-controls skills, commands, and settings, then symlinks them into `~/.claude/` via a Makefile.

## Setup

```bash
make install   # symlinks claude/* into ~/.claude/
```

No build step. Dependencies: `bash`, `jq`, `git`, `gh`, `bc`.

## Architecture

```
claude/
├── settings.json            # Main Claude Code config (statusLine, permissions, etc.)
├── statusline-command.sh    # Status bar script: parses harness JSON, renders 3-line display
├── commands/                # Custom slash commands (e.g. /todo)
└── skills/                  # Reusable workflow skills (e.g. /pr)
```

**Skills** (`skills/*/skill.md`) define multi-step workflows invoked as slash commands. Each skill declares its own `allowed-tools` frontmatter to restrict tool access.

**Commands** (`commands/*.md`) are lightweight Claude Code commands; they can disable model invocation with `disable-model: true` for pure tool-use flows.

**statusline-command.sh** receives JSON from the Claude Code harness on stdin and renders ANSI-colored output for the terminal status line.

## Key Conventions

- Skills explicitly list allowed tools (e.g. `allowed-tools: Bash(git:*), Bash(gh:*)`) — keep these minimal.
- The `install` Makefile target uses symlinks, so edits in this repo take effect immediately without re-running `make install`.
- GitHub workflows use the `gh` CLI exclusively (no direct API calls).
