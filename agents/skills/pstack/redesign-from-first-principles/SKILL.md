---
name: redesign-from-first-principles
description: "Read when a request changes how existing code must behave or adds a requirement it wasn't built for, such as a new case, input, platform or mode. Redesign as if the requirement had been there from the start instead of bolting it on, and update every type, doc and caller it touches."
---

# Redesign From First Principles

When integrating a change, don't bolt it onto the existing design. Redesign as if the requirement had been a foundational assumption from the start.

- Read all affected files and understand the current design
- Ask: "if we were writing this from scratch with this new requirement, what would we build?"
- Propagate the change through every reference: types, docs, examples, rationale sections
- Think about the whole redesign, then deliver it incrementally

This is the method for preserving option value when integrating changes into an existing design.
