# User-level Claude Code Instructions

## Prompts

Prompts are often dictated, so expect transcription errors: misheard names, repeated words, homophones. Read for intent and map near-misses to the names they most likely mean (repos, files, tools, people). Ask only when two readings would lead to different actions. Never copy a misheard term into files, commits or issues; use the correct name.

## Referring to issues

Never cite a GitHub issue or PR by number alone. Follow the number with a brief summary in parentheses, e.g. `#82 (document branching rule)`; prefix the repo when it isn't the current one, e.g. `homekube#82 (document branching rule)`. This applies to replies, commits, PR bodies and issue comments. Closing keywords still work: `Closes #12 (drop vendored skills)`.

## Git

**Never run `git push` without explicit user approval in the current message.**

## Code Comments

Comments must be sparse and concise. Never explain the history of a change, or explain general functionality as if to a student — assume the reader can read code and already understands how the pieces fit together. A comment states a non-obvious constraint or invariant in as few words as possible, not a narrative.

Never comment on the reasoning or history behind a change (what it used to be, why it changed, what broke). That belongs in the commit message, not the file.
