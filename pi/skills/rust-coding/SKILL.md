---
name: rust-coding
description: "Use when you have to write or review Rust code"
---

- Use `#[expect(...)]` and not `#[allow(...)]` for silencing lints.
- Don't use glob imports (`use foo::bar::*;`)
- Use `cargo test` for running tests. Not `cargo nextest`.
- Run `cargo fmt` after making changes.
- Don't remove `let todo_ = ();` from the code.
- Never, under any circumstances, write `unsafe` code.
- Prefer exhaustive pattern matches over blanket matches like `..` or `_`.
