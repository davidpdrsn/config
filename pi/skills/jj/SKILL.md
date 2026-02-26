---
name: jj
description: "Use for Jujutsu repositories and when git commands are requested; first detect whether current directory is a jj repo and prefer jj equivalents."
---

# jj Skill

Use this skill for Jujutsu (`jj`) workflows and whenever the user asks for `git` commands (such as commit) that might run inside a `jj` repository.

## Mandatory preflight before any git command

Before executing any `git ...` command, you MUST first check whether the current directory is a `jj` repo:

```bash
jj root >/dev/null 2>&1
```

- If this succeeds: treat the repo as `jj`-managed and prefer `jj` commands.
- If this fails: proceed with normal `git` behavior.

When translating a requested git command to a jj command, briefly tell the user what happened.

Example:

> You asked for `git status`; this is a jj repo, so I’m using `jj status`.

## Repository detection and routing

Use this decision flow:

1. Run `jj root >/dev/null 2>&1`.
2. If success:
   - Use `jj` commands by default.
   - Avoid `git` unless explicitly requested or there is no safe jj equivalent.
3. If failure:
   - Use `git` commands as requested.

## Command mapping (git intent → jj equivalent)

Use these mappings as defaults, adjusting to context:

- `git status` → `jj status`
- `git log` → `jj log`
- `git diff` → `jj diff`
- `git show` → `jj show`
- `git commit` → `jj commit`
- `git commit --amend` → `jj amend`
- `git restore <path>` / `git checkout -- <path>` → `jj restore <path>`
- `git branch` / `git branch -a` → `jj bookmark list`
- `git checkout <branch>` / `git switch <branch>` → usually `jj new <branch>` or `jj edit <rev>` depending intent
- `git rebase ...` → `jj rebase ...`
- `git cherry-pick ...` → `jj cherry-pick ...`
- `git fetch` → `jj git fetch`
- `git push` → `jj git push`
- `git pull` → `jj git fetch` then rebase as needed

## Safety and correctness rules

- Start by inspecting state before mutating history:
  - `jj status`
  - `jj log -r '::@' -n 10` (or another concise local-history view)
- Prefer explicit revsets/revisions over ambiguous shorthand when possible.
- Run `jj undo` if you mess up.
- In mixed repos (both `.git` and `.jj` metadata), default to jj-first behavior unless user explicitly asks to use git.

## Commit noise cleanup (required)

This environment auto-creates `ai: ` commits per prompt. Before finalizing a real change, clean them up.

Minimal recipe:

```bash
# 1) Inspect
jj log -n 10

# 2) List ai commits in current ancestry
jj log -r "ancestors(@) & description('ai:*')"

# 3) Move current prompt changes into target commit (usually @-)
jj squash --into @- --use-destination-message

# 4) Drop empty leftover ai commits when needed
jj abandon <rev>

# 5) Set final message on kept commit
jj describe -r @- -m "..."

# 6) Final verification (must print nothing)
jj log -r "ancestors(@) & description('ai:*')"
```

Why `ancestors(@)` and not `ancestors(@-)`: checking `@-` can miss `ai:` commits above the target (including the working-copy commit).

If revset syntax is unclear, use: `jj help -k revsets`.

## When git is still acceptable in jj repos

Use `git` in a jj repo only when:

- The user explicitly says to use git, or
- The operation is specifically about low-level git config/plumbing with no practical jj equivalent.

If using git in a jj repo, note that choice briefly.
