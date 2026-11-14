---
name: tmux
description: "Remote control tmux sessions for interactive CLIs (python, gdb, etc.) by sending keystrokes and scraping pane output."
license: Stolen from https://github.com/mitsuhiko/agent-stuff
---

# tmux Skill

Use tmux as a programmable terminal multiplexer for interactive work. Works on Linux and macOS with stock tmux; avoid custom config by using a private socket.

## Agent execution policy (MUST)

- The agent MUST execute the full end-to-end test flow itself inside tmux.
- Monitor/attach commands shown to the user are for observation and inspection, not for delegating execution.
- The agent MUST NOT stop at "here are commands for you to run" unless the user explicitly asked to take over.
- After printing monitor commands, continue running the test loop autonomously (send keys, wait/poll, capture output, and summarize results).

## Quickstart (isolated socket)

```bash
SOCKET_DIR=${TMPDIR:-/tmp}/claude-tmux-sockets  # well-known dir for all agent sockets
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/claude.sock"               # keep agent sessions separate from your personal tmux
SESSION=claude-python                            # slug-like names; avoid spaces
tmux -S "$SOCKET" new -d -s "$SESSION" -n shell
TARGET="$(tmux -S "$SOCKET" list-panes -t "$SESSION" -F '#{session_name}:#{window_index}.#{pane_index}' | head -n1)"
tmux -S "$SOCKET" send-keys -t "$TARGET" -- 'PYTHON_BASIC_REPL=1 python3 -q' Enter
tmux -S "$SOCKET" capture-pane -p -J -t "$TARGET" -S -200  # watch output
tmux -S "$SOCKET" kill-session -t "$SESSION"                # clean up
```

After starting a session, ALWAYS tell the user how to monitor the session by giving them a copy/paste command, then continue the testing yourself.

Use fish-safe commands (or absolute paths), never bash-only `${VAR:-default}` expansions in user-facing commands.

```text
To monitor this session yourself:
  tmux -S "$SOCKET" attach -t claude-lldb

Or to capture the output once:
  TARGET="$(tmux -S \"$SOCKET\" list-panes -t claude-lldb -F '#{session_name}:#{window_index}.#{pane_index}' | head -n1)" && tmux -S "$SOCKET" capture-pane -p -J -t "$TARGET" -S -200
```

For fish users, this also works well:

```fish
tmux -S "$TMPDIR/claude-tmux-sockets/claude.sock" attach -t claude-lldb
set -l TARGET (tmux -S "$TMPDIR/claude-tmux-sockets/claude.sock" list-panes -t claude-lldb -F '#{session_name}:#{window_index}.#{pane_index}' | head -n1); and tmux -S "$TMPDIR/claude-tmux-sockets/claude.sock" capture-pane -p -J -t "$TARGET" -S -200
```

This monitor command MUST be printed immediately after session start and again at the end of the tool loop. Do not wait for the user to run it before continuing.

## Expected workflow (required)

1. Start or attach to the tmux session.
2. Immediately print a copy/paste monitor command for the user.
3. Run the end-to-end test sequence yourself (send keys, wait/poll for prompts/output, capture pane output, and continue until completion).
4. Summarize what happened and the observed results.
5. Print final monitor/capture command(s) again and report cleanup status.

## Anti-patterns

Do not hand execution back to the user by default. Avoid responses like:
- "Here are commands for you to run."
- "Please run these and tell me what happened."

Prefer wording like:
- "I started the tmux test session; you can watch with: <monitor command>. I will run the full test sequence now and report results."

## Socket convention

- Agents MUST place tmux sockets under `CLAUDE_TMUX_SOCKET_DIR` (defaults to `${TMPDIR:-/tmp}/claude-tmux-sockets`) and use `tmux -S "$SOCKET"` so we can enumerate/clean them. Create the dir first: `mkdir -p "$CLAUDE_TMUX_SOCKET_DIR"`.
- Default socket path to use unless you must isolate further: `SOCKET="$CLAUDE_TMUX_SOCKET_DIR/claude.sock"`.
- In user-facing commands, prefer `$SOCKET` or an absolute socket path. Do not emit bash-only `${VAR:-default}` syntax in copy/paste commands.

## Targeting panes and naming

- Target format: `{session}:{window}.{pane}`. Do not assume a default window index (`0` vs `1` varies by tmux config). Resolve the first pane dynamically with `list-panes` and store it in `TARGET`.
- Use `-S "$SOCKET"` consistently to stay on the private socket path. If you need user config, drop `-f /dev/null`; otherwise `-f /dev/null` gives a clean config.
- Inspect: `tmux -S "$SOCKET" list-sessions`, `tmux -S "$SOCKET" list-panes -a`.

## Finding sessions

- List sessions on your active socket with metadata: `./scripts/find-sessions.sh -S "$SOCKET"`; add `-q partial-name` to filter.
- Scan all sockets under the shared directory: `./scripts/find-sessions.sh --all` (uses `CLAUDE_TMUX_SOCKET_DIR` or `${TMPDIR:-/tmp}/claude-tmux-sockets`).

## Sending input safely

- Prefer literal sends to avoid shell splitting: `tmux -S "$SOCKET" send-keys -t target -l -- "$cmd"`
- When composing inline commands, use single quotes or ANSI C quoting to avoid expansion: `tmux ... send-keys -t target -- $'python3 -m http.server 8000'`.
- To send control keys: `tmux ... send-keys -t target C-c`, `C-d`, `C-z`, `Escape`, etc.

## Watching output

- Capture recent history (joined lines to avoid wrapping artifacts): `tmux -S "$SOCKET" capture-pane -p -J -t target -S -200`.
- For continuous monitoring, poll with the helper script (below) instead of `tmux wait-for` (which does not watch pane output).
- You can also temporarily attach to observe: `tmux -S "$SOCKET" attach -t "$SESSION"`; detach with `Ctrl+b d`.
- When giving instructions to a user, **explicitly print a copy/paste monitor command** alongside the action don't assume they remembered the command.

## Spawning Processes

Some special rules for processes:

- when asked to debug, use lldb by default
- when starting a python interactive shell, always set the `PYTHON_BASIC_REPL=1` environment variable. This is very important as the non-basic console interferes with your send-keys.

## Synchronizing / waiting for prompts

- Use timed polling to avoid races with interactive tools. Example: resolve a pane target, then wait for a Python prompt before sending code:
  ```bash
  TARGET="$(tmux -S "$SOCKET" list-panes -t "$SESSION" -F '#{session_name}:#{window_index}.#{pane_index}' | head -n1)"
  ./scripts/wait-for-text.sh -t "$TARGET" -p '^>>>' -T 15 -l 4000
  ```
- For long-running commands, poll for completion text (`"Type quit to exit"`, `"Program exited"`, etc.) before proceeding.

## Interactive tool recipes

- **Python REPL**: `tmux ... send-keys -- 'python3 -q' Enter`; wait for `^>>>`; send code with `-l`; interrupt with `C-c`. Always with `PYTHON_BASIC_REPL`.
- **gdb**: `tmux ... send-keys -- 'gdb --quiet ./a.out' Enter`; disable paging `tmux ... send-keys -- 'set pagination off' Enter`; break with `C-c`; issue `bt`, `info locals`, etc.; exit via `quit` then confirm `y`.
- **Other TTY apps** (ipdb, psql, mysql, node, bash): same pattern—start the program, poll for its prompt, then send literal text and Enter.

## Cleanup

- Kill a session when done: `tmux -S "$SOCKET" kill-session -t "$SESSION"`.
- Kill all sessions on a socket: `tmux -S "$SOCKET" list-sessions -F '#{session_name}' | xargs -r -n1 tmux -S "$SOCKET" kill-session -t`.
- Remove everything on the private socket: `tmux -S "$SOCKET" kill-server`.

## Helper: wait-for-text.sh

`./scripts/wait-for-text.sh` polls a pane for a regex (or fixed string) with a timeout. Works on Linux/macOS with bash + tmux + grep.

```bash
./scripts/wait-for-text.sh -t session:window.pane -p 'pattern' [-F] [-T 20] [-i 0.5] [-l 2000]
```

- `-t`/`--target` pane target (required)
- `-p`/`--pattern` regex to match (required); add `-F` for fixed string
- `-T` timeout seconds (integer, default 15)
- `-i` poll interval seconds (default 0.5)
- `-l` history lines to search from the pane (integer, default 1000)
- Exits 0 on first match, 1 on timeout. On failure prints the last captured text to stderr to aid debugging.
