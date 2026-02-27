---
name: openclaw-runtime-packages
description: "Use when adding tools for OpenClaw on hetzner-2. Ensures required CLIs are added to openclawPackages so agent exec can find them."
---

# openclaw-runtime-packages

Use this skill when changing tooling that OpenClaw agents should execute on `hetzner-2`.

## When to use

- User asks to add/install a CLI for OpenClaw workflows
- `openclaw agent` says `command not found`
- You add scripts/skills that call a binary from agent `exec`
- You modify OpenClaw-related tooling in this repo

## Mandatory rule

If OpenClaw agents on `hetzner-2` must run a command by name, the package **must** be included in:

`nix/machines/hetzner-2/configuration.nix` → `openclawPackages`

Do not rely only on shared/global package lists.

## Why

`openclawPackages` is used to create runtime symlinks into `~/config/bin`, which is exposed via `~/.bin` for OpenClaw runtime. If a tool is only installed elsewhere, OpenClaw agent exec may not find it.

## Required implementation steps

1. Add package derivation/binding if needed.
2. Add package to `openclawPackages` in `nix/machines/hetzner-2/configuration.nix`.
3. Keep skill/script command invocation by name (for example `cloud-agent`).

## Required verification

After changes:

```bash
just test
```

If nix files changed:

```bash
just check && just build
```

Runtime checks on server:

```bash
ssh hetzner-2 'command -v <tool>'
ssh hetzner-2 'ls -l ~/config/bin/<tool>'
```

If relevant, smoke-test via OpenClaw:

```bash
ssh hetzner-2 'openclaw agent --agent main --message "Run <tool> and summarize output."'
```

## Common failure mode to prevent

Tool exists on system, but OpenClaw says `command not found` because it was not added to `openclawPackages`.
