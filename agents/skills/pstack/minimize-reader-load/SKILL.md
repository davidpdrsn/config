---
name: minimize-reader-load
description: "Read when reviewing code or a diff, and when writing code that adds a wrapper, adapter, trait, one-caller helper, struct field or shared mutable state. Collapse layers that only forward calls and shrink the scope of mutable state, so a reader can tell where a value comes from and what changes it."
---

# Minimize Reader Load

Reader load is the work a reader must do to understand code. It has two independent axes: layers to trace between the question and the answer, and hidden or mutable state to hold in their head. Guard both.

- Collapse layers that only forward: wrappers with one caller, adapters with no second implementation, pass-through methods. Inline them.
- Shrink state scope: returns over mutations, locals over fields, fields over module state, module state over globals. Derive instead of sync.
- Name an invariant once at the boundary, not in every consumer.

The test: can a new reader answer "where does X come from?" and "what can change X?" in under 30 seconds? If not, cut layers or cut state.
