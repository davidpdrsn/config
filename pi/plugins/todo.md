# Todo plugin (`pi/plugins/todo.ts`)

This plugin adds an OpenCode-style todo workflow to pi.

## What it provides

- Tool: `todowrite`
  - Replaces the full todo list (ordered)
  - Persisted in tool result `details` (session-backed)
- Tool: `todoread`
  - Returns current todo list snapshot
- Command: `/todos`
  - Opens a read-only TUI view of the current branch's todos
- Widget:
  - Shows completion summary below the editor only when there are open todos (`pending` or `in_progress`)
- Plan-execution nudge:
  - When plan mode exits via exact `go` prompt transform, the plugin injects a strong reminder to create/update todos first.

## Todo model

Each item has:

- `id: string`
- `content: string`
- `status: "pending" | "in_progress" | "completed" | "cancelled"`

No priority field is used (all todos have equal priority).

## Persistence + branch behavior

State is reconstructed from current branch history by scanning `toolResult` messages for `todowrite`/`todoread` details on:

- `session_start`
- `session_switch`
- `session_fork`
- `session_tree`

This keeps todos branch-correct without external storage.
