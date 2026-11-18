---
name: code-review
description: "Use when reviewing code, such as a branch, a diff or a pull request"
metadata:
  group: review
---

Look for these, most important first:

1. Bugs that normal users can hit. Skip edge cases normal users never hit.
2. Duplication that the change added.
3. Refactors that make the change simpler, such as removing code the change made unnecessary or giving what it added a simpler shape.

For each bug, list the steps to reproduce it. If you can't find a way to reproduce it, say so.

Skip these, and don't mention that you skipped them:

- Building, running checks or tests, and reporting possible type errors. The author has done that, and CI catches what they missed.
- Formatting and style nits, such as commas and indentation.
