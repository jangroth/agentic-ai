---
name: dotfiles
description: Use when editing the user's dotfiles from any directory — neovim/vim mappings, zsh aliases/functions, git/tmux/starship/vscode/ghostty config. Triggers on "my neovim config", "add a zsh alias", "dotfiles", "my vim mapping", "my shell function". Points to the ~/Projects/dotfiles repo layout and workflow rules so edits land correctly even when cwd is elsewhere.
allowed-tools: Bash(git:*), Bash(make:*)
---
# Dotfiles

Repo: `~/Projects/dotfiles` (main branch is default/protected).

## Structure
- `files/` — actual config, symlinked/copied into `$HOME` by scripts
  - `zsh/` — `zshenv` (all shells), `zprofile` (login), `zshrc` (interactive)
  - `shell/aliases`, `shell/functions/` — sourced by zshrc; functions auto-load from `~/.zsh/functions/`
  - `vim/`, `git/`, `tmux/`, `starship/`, `vscode/`, `ghostty/`, `help/`
- `scripts/NN_setup_*.sh` — one per `files/` subdir, installs/symlinks into `$HOME`
- `scripts/_config.sh` — shared config (`$DOT_OS`, `$DOT_ROOT`, `confirm_binaries`)

## Workflow (applies even when invoked from another cwd)
1. `cd ~/Projects/dotfiles`, create a feature branch off `main` before editing — never commit to main directly.
2. Run `make lint` before committing.
3. Update `README.md` if the change affects setup, usage, or tooling.
4. Never push without explicit confirmation in the current message.
5. For new CLI commands/shell functions, ask about interface (args, completion) before coding.

## Platform notes
- Linux uses `fdfind`; macOS uses `fd` (Docker image symlinks `~/.local/bin/fd → fdfind`).
- `$PROJECTS_HOME` resolves to `~/Projects` (macOS) / `~` (Linux), set in `zprofile`.

For anything not covered here, read `~/Projects/dotfiles/CLAUDE.md` — it's the source of truth.
