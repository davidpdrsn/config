---
name: cloud-agent-status
description: "MANDATORY for cloud agent status checks: inspect active /cloud agents via cloud-tmux-status."
always: true
---

# cloud-agent-status

Use this skill when the user asks about status/progress/health of cloud agents started by `/cloud`.

Trigger examples:
- "are cloud agents running"
- "check cloud status"
- "what is /cloud doing"
- "any active cloud agents"

## Primary command

Run:

```bash
cloud-tmux-status
```

This command is mandatory for cloud-status questions. Do not infer status from memory or other tools; always execute `cloud-tmux-status` first.

If this command is not run, you must explicitly say status is unknown and run it before answering.

This returns structured JSON with active cloud tmux sessions, inferred state, and counts.

## How to respond

1. Summarize the high-level counts first (`running`, `done`, `blocked`, `failed`).
2. Then list each session with:
   - `session`
   - `state`
   - `bookmark` (if present)
   - `workspace` (if present)
   - `lastLine` (short progress clue)
3. If no sessions are present, clearly say there are no active cloud sessions.

## Debug mode

If the state looks wrong or unclear, rerun with pane output included:

```bash
cloud-tmux-status --include-pane
```

Use this only when needed (it is verbose).

## Output discipline

- Keep responses concise and operational.
- Do not paste huge raw pane dumps unless explicitly asked.
- Treat missing `Status:` fields as normal for still-running agents.
