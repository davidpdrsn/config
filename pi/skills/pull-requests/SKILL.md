---
name: pull-requests
description: "Use when told to open pull requests or 'ship it'"
---

Use `but pr new BRANCH` to open the pull request

- If the branch contains exactly one commit use the message of the commit as the PR description. GitButler does this automatically.
- If the branch contains multiple commits leave the description empty. Generate a title yourself.
- Never generate PR descriptions without explicit permission.
- Enable auto merge
