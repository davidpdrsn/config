---
name: ship-it
description: "Use when told to 'ship it' or to ship a branch"
---

Shipping a branch means opening its pull request with `but pr new <branch>` and enabling auto-merge.

- If the branch has exactly one commit, run `but pr new <branch> -t`. GitButler uses the commit message as the PR title and description.
- If the branch has several commits, write a title yourself and leave the description empty: `but pr new <branch> -m '<title>'`.
- Never write a PR description without explicit permission.
- Enable auto-merge on the pull request.
