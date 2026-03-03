---
name: openclaw-notify
description: "Use to send concise task status notifications via OpenClaw using `openclaw-msg`."
---

# openclaw-notify

Use this skill only when the user explicitly asks for OpenClaw notifications.

## Command

Send notifications with:

```bash
openclaw-msg "<message>"
```

## Mandatory rule

Do not send OpenClaw notifications by default.

Only send notifications when the user explicitly asks for them.

## When to notify

Notify only if the user has explicitly requested OpenClaw notifications for the current task.

If not explicitly requested, do not call `openclaw-msg`.

When notifications are requested, send only meaningful updates:

- Task completed
- Task failed
- Long-running task started (optional)
- Long-running task finished

Avoid noisy per-step updates unless the user explicitly asks for that level of detail.

## Message format

Keep messages short and actionable:

- Prefix with project/context
- Include status (`started`, `done`, `failed`)
- Include one-line result

Examples:

```bash
openclaw-msg "[config] started: rebuilding nix configuration"
openclaw-msg "[config] done: just test passed"
openclaw-msg "[config] failed: just build failed (see logs)"
```

## Safety rules

- Always quote message text.
- Do not include secrets, tokens, or private keys.
- If the command fails, continue the main task and report the notification failure in normal output.

## Preflight (optional)

If command availability is uncertain:

```bash
command -v openclaw-msg
```

If missing in OpenClaw runtime on `hetzner-2`, use the `openclaw-runtime-packages` skill and add it to `openclawPackages`.
