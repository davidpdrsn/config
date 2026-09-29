# agent-status

`agent-status` reports whether local Pi agents are busy, idle, waiting for input, offline, or unknown.

## Commands

```bash
# JSON output (default)
agent-status

# one-line output (for tmux/prompt)
agent-status --summary

# table output
agent-status --table
```

## Output states

- `busy`: agent is actively processing
- `idle`: agent is running and waiting for input
- `waiting_input`: agent is blocked on an interactive question
- `offline`: status file exists but process is no longer alive
- `unknown`: process is alive but heartbeat is stale

## Untouched sessions and mux recovery

Status records include `untouched`, an explicit indication that the session has no
conversation history or queued input. It is initialized from the entire session
tree on startup/reload and cleared on input (including extension input), agent
activity, messages, and user bash commands. Returning to idle does not reset it.
Status writes are ordered so an old heartbeat cannot overwrite a newer report.

Mux can reopen an idle, untouched Pi as a fresh instance when Pi has not created
its session file yet. A missing file or an idle status alone is not sufficient.
Existing files still use normal conversation recovery. Run `/reload` in already
open Pi instances after updating this extension to publish the new field.

## Tmux example

```tmux
set -g status-right '#(agent-status --summary 2>/dev/null) | %H:%M'
```

## Prompt example

```bash
agent-status --summary 2>/dev/null
```

## Runtime directory discovery

`agent-status` auto-discovers status files from:

1. `PI_AGENT_STATUS_DIR` (if set)
2. `${TMPDIR:-/tmp}/pi-agent-status`
3. `/tmp/nix-shell.*/pi-agent-status`

When duplicate PIDs exist across directories, the newest `updatedAt` record wins.
