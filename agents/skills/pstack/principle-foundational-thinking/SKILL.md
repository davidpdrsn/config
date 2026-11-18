---
name: principle-foundational-thinking
description: "Apply when writing or changing code, including bug fixes"
---

Use use principle-foundational-thinking skill when using this.

# Foundational Thinking

Get the data shape right before writing logic. Define core types early, trace every access pattern, and choose structures that match the dominant paths. DRY the structure, not every line.

Before sharing state between actors, ask what happens if another actor modifies it. If the answer is not "nothing", isolate.

Scaffold first. Whatever helps every later phase (CI, tests, shared types) goes first, after removing dead code. Keep commits small and single-purpose.

Always invest in making the underlying data model more robust.
