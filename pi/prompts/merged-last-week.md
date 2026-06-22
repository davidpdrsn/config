---
description: List non-merge commits I authored that were merged last week using only local git history
argument-hint: "[author-pattern]"
---

Find the non-merge commits that I authored and merged last week using only local repository data.

Use local git history only. Do not fetch, pull, push, or call network services.

Interpret "last week" as the previous calendar week in the local timezone, Monday 00:00 through the following Monday 00:00. If an author pattern is provided, use it for both the merge commits and introduced commits; otherwise use the local git identity from `git config user.name` / `git config user.email`.

Suggested local approach:

1. Determine the previous calendar week's start and end timestamps locally.
2. Find merge commits in that range authored by `${ARGUMENTS:-the local git user}`.
3. For each merge commit, ignore the merge commit itself and list only non-merge commits introduced by its non-first parent(s), excluding commits already reachable from the first parent. A good range shape is:
   `git log --no-merges --reverse --author=<author-pattern> <second-and-later-parents> ^<first-parent>`.
4. Exclude any introduced commit whose author does not match the author pattern. This command is about commits I authored, not commits by other people that I merged.
5. Report one commit per line, without grouping by merge or PR: `<short-hash> <subject>`.
6. Note the date range.

Example output

   45af38dc09 feat(tui): more consistent scroll key binds
   1de4406a4f fix(tui): show more accurate message if we can't show diff
   15aa085df1 fix(tui): dont tell agents to use cargo-nextest for tui testing
   960b1f2a0d fix(tui): fix committing all unassigned changes to new branch
   c4953a3c78 refactor(tui): make reusable pop up component

Do not print merge commits. Do not print commits authored by someone else, even if I authored the merge commit that introduced them.
