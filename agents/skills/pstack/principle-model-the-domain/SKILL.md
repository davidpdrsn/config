---
name: principle-model-the-domain
description: "Apply when writing or changing code, including bug fixes"
metadata:
  group: code
---

# Model the Domain

Lean on the type system. Encode the domain in a data structure instead of scattering it across conditionals. The right structure makes invalid states unrepresentable and deletes branches.

Parse, don't validate. Use newtypes. Treat bare strings and bools as smells. Use newtypes instead of strings and enums with yes/no variants instead of bools.

Prefer pure functions.

Reach for a state machine instead of scattered booleans or phase checks, a typed model instead of loose parameters, a map, registry, or discriminated union instead of branching spread across files, a reducer instead of ad hoc mutations, and an index, queue, or normalized collection where the access pattern calls for it.

Aggressively move callers to your new data models. Don't keep legacy code around without a good reason.

Do not force it. Keep boring code when the shape is clear, local, and unlikely to grow, and distrust an abstraction that adds indirection without removing branches or invalid states.

The sign that you skipped this: a feature that grows an if/else chain by one more branch, or a second boolean that must stay in sync with the first.
