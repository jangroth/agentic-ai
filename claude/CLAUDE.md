# User-level Claude Code Instructions

## Prompts

Prompts are often dictated, so expect transcription errors: misheard names, repeated words, homophones. Read for intent and map near-misses to the names they most likely mean (repos, files, tools, people). Ask only when two readings would lead to different actions. Write the correct name in files, commits and issues, never the misheard term.

## Referring to issues and ADRs

Cite a GitHub issue, PR or ADR by its number followed by a brief summary in parentheses, e.g. `#82 (document branching rule)` or `ADR-0003 (merge commits only)`; prefix the repo when it isn't the current one, e.g. `homekube#82 (document branching rule)`. This applies to replies, commits, PR bodies, issue comments and docs. Closing keywords still work: `Closes #12 (drop vendored skills)`.

## Times

Give times in Sydney local time (AEDT or AEST, whichever is current), with the zone and, unless it's today, the date. GitHub, git and most APIs report UTC: convert before stating a time or saying "yesterday"/"today" (`TZ=Australia/Sydney date`).

## Issue labels

Every repo uses the mattpocock-skills triage labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`; category labels `bug`, `enhancement`. A repo's `CLAUDE.md` may add labels of its own.

`ready-for-agent` means an agent may implement it unattended, so beyond being fully specified the fix must be unambiguous, reversible and PR-only, with no open design decision and no physical or external-account step. Check this before applying the label, including when a skill applies it automatically; if it doesn't hold, use `needs-triage` or `ready-for-human`.

## Git

**Never run `git push` without explicit user approval in the current message.**

Never commit to `main`. Every change reaches it through a PR, rebased onto `main` before merging (GitHub's "Update with rebase" will do when there's no conflict) and merged with a merge commit, never squashed or rebase-merged. A repo's `CLAUDE.md` states only its exceptions.

## Code Comments

Comments are sparse: one line stating a non-obvious constraint or invariant, written for a reader who already knows the code. Change history and rationale belong in the commit message.
