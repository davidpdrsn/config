---
name: code-review
description: "Use this skill when reviewing code"
---

Keep these things in mind when reviewing code:

- Don't build, run checks, or report potential type errors. Trust the human to have done that, otherwise CI will catch it.
- Don't run tests. Trust that the human has ensured they pass, otherwise CI will catch it.
- Don't review formatting such as commas, indentation, etc

Do not say that you didn't review these. Silently ignore them.

If asked to review branches some helpful commands are:
- `/Users/davidpdrsn/code/gitbutler/gitbutler-git/target/release/but show BRANCH` to find commits on the branch
- `/Users/davidpdrsn/code/gitbutler/gitbutler-git/target/release/but diff BRANCH` to see changes on branch
