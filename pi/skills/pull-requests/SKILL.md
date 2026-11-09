---
name: pull-requests
description: "Use when told to open pull requests or 'ship it'"
---

Use `but pr new BRANCH` to open the pull request

- If the branch contains exactly one commit use the message of the commit as the PR description. GitButler does this automatically.
- If the branch contains multiple commits leave the description empty. Generate a title yourself.
- Never generate PR descriptions without explicit permission.
- Enable auto merge
- Once the PR has merged, walk up your process tree and quit the shell that started the agent and the terminal multiplexer or session manager hosting that shell, leaving everything above it running; if the PR is closed or a check fails, quit nothing and tell the user
