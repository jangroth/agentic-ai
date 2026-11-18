---
description: File a TODO as a GitHub issue, labelled for triage
disable-model-invocation: true
---

File this TODO as a GitHub issue: $ARGUMENTS

1. Repo: the current one, unless its `CLAUDE.md` names a different tracker (homekube-main and homekube-apps file on `jangroth/homekube`).
2. Title: the TODO as given. Body: empty, or one or two lines if this conversation gives context worth keeping.
3. Label `needs-triage` only. If the repo lacks it, create it: `gh label create needs-triage --description "Maintainer needs to evaluate this issue"`.
4. Assign `@me`.

Never add `ready-for-agent`; that's for `/triage`.

Reply with the issue URL.
