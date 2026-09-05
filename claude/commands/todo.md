---
description: Create a new GitHub issue as a TODO item
disable-model-invocation: true
---

Create a new GitHub issue as a TODO item.

The user wants to add this TODO: $ARGUMENTS

Run:
```
gh issue create --title "$ARGUMENTS" --label todo --label agent-safe --assignee "@me" --body ""
```

Then confirm with the issue URL.
