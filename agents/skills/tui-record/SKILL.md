---
name: tui-record
description: Record a terminal app as an mp4 or take PNG screenshots of it with the `tui-record` CLI, driving it with keys and mouse events. Use it to prove that a TUI feature or fix works, or to show a TUI bug, for example when sending proof through Prove It.
---

# tui-record

`tui-record` runs a terminal app in its own tmux server, sends it keys and mouse events, and records the screen. `stop -o demo.mp4` turns the recording into a video. `screenshot` renders the current screen as a PNG.

Use a video for a flow, and a screenshot for a single state.

## Example

```sh
tui-record start --size 110x34 --wait-for "Welcome" -- my-app --flag
tui-record screen -n                        # look before you act
tui-record type "hello"
tui-record key Enter
tui-record drag "first word" "last word."   # select text with the mouse
tui-record wait "Saved"
tui-record click "OK"
tui-record screenshot state.png
tui-record stop -o demo.mp4
```

Run `tui-record --help` and `tui-record <command> --help` for every option.

## Commands

- `start [--size COLSxROWS] [--cwd DIR] [--wait-for TEXT] [--no-record] -- COMMAND...` starts the app and the recording. Use `--no-record` when you only need screenshots.
- `screen [-n] [--ansi]` prints the screen as text. `-n` adds row numbers.
- `find TEXT` prints `col,row` for every match.
- `type TEXT` types one character at a time.
- `key KEY...` presses keys by their tmux names, such as `Enter`, `Escape`, `Tab`, `BSpace`, `Up`, `C-c` and `M-x`.
- `move TARGET`, `click TARGET [--double] [--button right]`, `drag START END` and `scroll up|down [--lines N] [--at TARGET]` send mouse events. The pointer moves there in small steps so viewers can follow it.
- `wait TEXT [--gone] [--timeout S]` waits until TEXT appears, or disappears with `--gone`.
- `screenshot OUT.png [--no-pointer]` renders the current screen.
- `stop [-o OUT.mp4] [--max-idle S] [--keep]` stops the app and renders the video.

A target is `col,row` (1-based) or text on the screen. Clicking text clicks its middle character. `drag` starts at the first character of START and ends at the last character of END, so `drag "With" "bucket."` selects everything from "With" through "bucket.". When text appears more than once, use `--nth` and `--end-nth`, or coordinates from `find`.

Use `--session NAME` before the command, or set `TUI_RECORD_SESSION`, to run several sessions at once.

## How to get a good recording

- Run `screen -n` or `find` before each mouse action. Don't guess coordinates. The layout moves when the app redraws, for example when an input grows.
- Use `wait` instead of `sleep` after actions that take time.
- Your pauses between commands are cut down to `--max-idle` seconds (default 2), so you can take your time. To let a state show for longer in the video, `sleep` between commands and raise `--max-idle`.
- Run the app on throwaway data. For pi, make a session in a temporary directory with `pi --session-dir DIR --model "anthropic/claude-haiku-4-5:off" -p "..."`, then start `pi --session-dir DIR -c`.
- Watch the result before sending it. Pull a frame with `ffmpeg -ss 5 -i demo.mp4 -frames:v 1 frame.png` and read it.
- In the Prove It message, say the video was recorded with `tui-record`, and list the steps it shows.

## What to know

- The app runs in a private tmux server (`tmux -L tui-record-<session>`), so it doesn't touch the user's tmux. Inside it, `TERM` is `tmux-256color` and `COLORTERM` is `truecolor`.
- Mouse events use SGR mouse encoding. Apps that only turn on older mouse modes won't understand them.
- The video shows the mouse pointer as a pink cell.
- `start` saves the macOS clipboard and `stop` restores it, because apps that copy on select overwrite it.
- Rendering runs freeze once per changed frame, in parallel. Expect about 20 seconds for 50 frames.
- Characters missing from freeze's font show as boxes.
- If rendering fails, `stop` keeps the frames and prints where they are.
