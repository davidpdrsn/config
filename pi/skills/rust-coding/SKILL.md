---
name: rust-coding
description: "Use when you have to write Rust code"
---

# Rust Coding Skill

- Use `#[expect(...)]` and not `#[allow(...)]` for silencing lints.
- Don't use glob imports (`use foo::bar::*;`)
- Use `cargo nextest` for running tests. Not `cargo test`.
- Run `cargo fmt` after making changes.
- Don't remove `let todo_ = ();` from the code.
