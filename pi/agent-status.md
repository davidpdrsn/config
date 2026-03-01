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

## Tmux example

```tmux
set -g status-right '#(agent-status --summary 2>/dev/null) | %H:%M'
```

## Prompt example

```bash
agent-status --summary 2>/dev/null
```

## Runtime directory

By default status files are written to:

- `${TMPDIR:-/tmp}/pi-agent-status`

Override with:

```bash
export PI_AGENT_STATUS_DIR=/custom/path
```
