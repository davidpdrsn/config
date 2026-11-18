#!/usr/bin/env python3
"""Drive a terminal app in a private tmux server and record it as a video.

Each command acts on one session, so an agent can look at the screen between
steps. See `tui-record --help` and agents/skills/tui-record/SKILL.md.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import unicodedata

CAPTURE_INTERVAL = 0.06
MOUSE_STEP_DELAY = 0.035
DEFAULT_FG = (205, 214, 244)
DEFAULT_BG = (30, 30, 46)
POINTER_BG = (243, 139, 168)
ANSI_16 = [
    (69, 71, 90), (243, 139, 168), (166, 227, 161), (249, 226, 175),
    (137, 180, 250), (245, 194, 231), (148, 226, 213), (186, 194, 222),
    (88, 91, 112), (243, 139, 168), (166, 227, 161), (249, 226, 175),
    (137, 180, 250), (245, 194, 231), (148, 226, 213), (166, 173, 200),
]
BUTTONS = {"left": 0, "middle": 1, "right": 2}


class Error(Exception):
    pass


# Session state ---------------------------------------------------------------


class Session:
    def __init__(self, name):
        if not re.fullmatch(r"[A-Za-z0-9_.-]+", name):
            raise Error(f"invalid session name {name!r}")
        self.name = name
        self.dir = Path(tempfile.gettempdir()) / "tui-record" / name
        self.socket = f"tui-record-{name}"

    @property
    def meta_path(self):
        return self.dir / "meta.json"

    @property
    def pointer_path(self):
        return self.dir / "pointer.json"

    @property
    def frames_dir(self):
        return self.dir / "frames"

    def exists(self):
        return self.meta_path.exists()

    def meta(self):
        if not self.exists():
            raise Error(f"no session {self.name!r}. Start one with `tui-record start -- COMMAND`")
        return json.loads(self.meta_path.read_text())

    def tmux(self, *args, check=True):
        result = subprocess.run(
            ["tmux", "-L", self.socket, "-f", "/dev/null", *args],
            capture_output=True, text=True,
        )
        if check and result.returncode != 0:
            raise Error(f"tmux {' '.join(args)}: {result.stderr.strip()}")
        return result

    def alive(self):
        return self.tmux("has-session", "-t", "app", check=False).returncode == 0

    def capture(self, ansi):
        args = ["capture-pane", "-p", "-t", "app"] + (["-e"] if ansi else [])
        return self.tmux(*args).stdout

    def pointer(self):
        try:
            return tuple(json.loads(self.pointer_path.read_text()))
        except (FileNotFoundError, ValueError):
            return None

    def set_pointer(self, x, y):
        tmp = self.pointer_path.with_suffix(".tmp")
        tmp.write_text(json.dumps([x, y]))
        tmp.replace(self.pointer_path)

    def send_literal(self, text):
        # Hex avoids tmux parsing ";" and other characters in arguments.
        self.tmux("send-keys", "-t", "app", "-H", *(f"{b:02x}" for b in text.encode()))


# Screen text and targets -----------------------------------------------------


def char_width(char):
    if unicodedata.combining(char):
        return 0
    return 2 if unicodedata.east_asian_width(char) in ("W", "F") else 1


def display_width(text):
    return sum(char_width(c) for c in text)


def find_text(screen, text):
    """Return (col, row, width) for each match, 1-based, in screen order."""
    matches = []
    for row, line in enumerate(screen.split("\n"), start=1):
        start = line.find(text)
        while start != -1:
            matches.append((display_width(line[:start]) + 1, row, display_width(text)))
            start = line.find(text, start + 1)
    return matches


def resolve(session, target, nth=1, anchor="middle"):
    """Turn `col,row` or on-screen text into a 1-based (col, row)."""
    coords = re.fullmatch(r"\s*(\d+)\s*,\s*(\d+)\s*", target)
    if coords:
        return int(coords[1]), int(coords[2])
    matches = find_text(session.capture(ansi=False), target)
    if len(matches) < nth:
        found = f"{len(matches)} match{'es' if len(matches) != 1 else ''}"
        raise Error(f"{target!r} is not on screen ({found}, wanted match {nth}). Run `tui-record screen`")
    col, row, width = matches[nth - 1]
    offset = {"start": 0, "middle": (width - 1) // 2, "end": width - 1}[anchor]
    return col + offset, row


# Input -----------------------------------------------------------------------


def mouse_event(session, button_code, x, y, release=False, delay=MOUSE_STEP_DELAY):
    session.send_literal(f"\x1b[<{button_code};{x};{y}{'m' if release else 'M'}")
    session.set_pointer(x, y)
    time.sleep(delay)


def glide(session, button_code, start, end, steps):
    (x0, y0), (x1, y1) = start, end
    for i in range(1, steps + 1):
        x = round(x0 + (x1 - x0) * i / steps)
        y = round(y0 + (y1 - y0) * i / steps)
        mouse_event(session, button_code, x, y)


def move_to(session, point, steps):
    current = session.pointer()
    if current is None or steps <= 1:
        mouse_event(session, 35, *point)
    else:
        glide(session, 35, current, point, steps)


# Recording -------------------------------------------------------------------


def record_loop(session):
    """Capture frames until the stop file appears or the app exits."""
    frames = session.frames_dir
    frames.mkdir(parents=True, exist_ok=True)
    index = open(frames / "index.jsonl", "a")
    last = None
    count = 0
    stop = session.dir / "stop"
    while not stop.exists():
        try:
            screen = session.capture(ansi=True)
        except Error:
            break
        pointer = session.pointer()
        if (screen, pointer) != last:
            name = f"{count:05d}.ansi"
            (frames / name).write_text(screen)
            index.write(json.dumps({"t": time.time(), "file": name, "pointer": pointer}) + "\n")
            index.flush()
            last = (screen, pointer)
            count += 1
        time.sleep(CAPTURE_INTERVAL)
    index.write(json.dumps({"t": time.time(), "end": True}) + "\n")
    index.close()


def stop_recorder(session, meta):
    pid = meta.get("recorder_pid")
    if not pid:
        return
    (session.dir / "stop").touch()
    deadline = time.time() + 5
    while time.time() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return
        time.sleep(0.05)
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass


# Rendering -------------------------------------------------------------------

SGR_OR_ESCAPE = re.compile(r"\x1b\[([0-9;:]*)m|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[P_^][^\x1b]*\x1b\\|\x1b\[[0-9;?]*[A-Za-z]")


def color_256(n):
    if n < 16:
        return ANSI_16[n]
    if n < 232:
        n -= 16
        levels = [0, 95, 135, 175, 215, 255]
        return levels[n // 36], levels[(n // 6) % 6], levels[n % 6]
    gray = 8 + (n - 232) * 10
    return gray, gray, gray


def apply_sgr(style, params):
    codes = [int(p) if p else 0 for p in re.split(r"[;:]", params)] if params else [0]
    i = 0
    while i < len(codes):
        code = codes[i]
        if code == 0:
            style.clear()
        elif code in (1, 2, 3, 4, 7, 9):
            style[code] = True
        elif code == 22:
            style.pop(1, None)
            style.pop(2, None)
        elif code in (23, 24, 27, 29):
            style.pop(code - 20, None)
        elif 30 <= code <= 37 or 90 <= code <= 97:
            style["fg"] = ANSI_16[code - 30 if code < 90 else code - 82]
        elif 40 <= code <= 47 or 100 <= code <= 107:
            style["bg"] = ANSI_16[code - 40 if code < 100 else code - 92]
        elif code in (39, 49):
            style.pop("fg" if code == 39 else "bg", None)
        elif code in (38, 48) and i + 1 < len(codes):
            key = "fg" if code == 38 else "bg"
            if codes[i + 1] == 5 and i + 2 < len(codes):
                style[key] = color_256(codes[i + 2])
                i += 2
            elif codes[i + 1] == 2 and i + 4 < len(codes):
                style[key] = tuple(codes[i + 2:i + 5])
                i += 4
        i += 1


def sgr_for(style, pointer=False):
    fg = style.get("fg", DEFAULT_FG)
    bg = style.get("bg")
    if style.get(7):
        fg, bg = bg or DEFAULT_BG, fg
    if pointer:
        fg, bg = DEFAULT_BG, POINTER_BG
    parts = ["0"]
    parts += [str(k) for k in (1, 2, 3, 4, 9) if style.get(k)]
    parts.append("38;2;%d;%d;%d" % fg)
    if bg:
        parts.append("48;2;%d;%d;%d" % bg)
    return "\x1b[" + ";".join(parts) + "m"


def normalize_frame(screen, width, pointer):
    """Spell out every cell's colors and draw the pointer.

    freeze cannot draw inverse video and resets styles at each line end, so
    each run of text gets explicit colors. Every line is padded to the pane
    width so all frames render at the same size.
    """
    out = []
    style = {}
    for row, line in enumerate(screen.removesuffix("\n").split("\n"), start=1):
        cells = []
        pos = 0
        for match in SGR_OR_ESCAPE.finditer(line):
            cells += [(char, dict(style)) for char in line[pos:match.start()]]
            if match.group(1) is not None:
                apply_sgr(style, match.group(1))
            pos = match.end()
        cells += [(char, dict(style)) for char in line[pos:]]
        # tmux trims trailing blank cells, so pad with default colors.
        col = 1
        rendered = ""
        for char, cell_style in cells + [(" ", {})] * max(0, width - display_width("".join(c for c, _ in cells))):
            rendered += sgr_for(cell_style, pointer is not None and (col, row) == tuple(pointer)) + char
            col += char_width(char)
        out.append(rendered + "\x1b[0m")
    return "\n".join(out)


def png_size(path):
    with open(path, "rb") as f:
        header = f.read(24)
    return struct.unpack(">II", header[16:24])


def render_png(ansi, out_path, work_dir):
    src = Path(work_dir) / (Path(out_path).stem + ".ansi")
    src.write_text(ansi)
    result = subprocess.run(
        ["freeze", "-x", f"cat {shlex.quote(str(src))}", "-o", str(out_path),
         "--window", "--background", "#%02x%02x%02x" % DEFAULT_BG],
        capture_output=True, text=True,
    )
    if result.returncode != 0 or not Path(out_path).exists():
        raise Error(f"freeze failed: {result.stderr.strip() or result.stdout.strip()}")


def render_video(session, meta, output, max_idle, end_hold):
    entries = [json.loads(line) for line in (session.frames_dir / "index.jsonl").read_text().splitlines() if line]
    frames = [e for e in entries if "file" in e]
    if not frames:
        raise Error("no frames were recorded")
    end_time = next((e["t"] for e in entries if e.get("end")), frames[-1]["t"])
    work = session.dir / "render"
    shutil.rmtree(work, ignore_errors=True)
    work.mkdir()

    def render(i):
        frame = frames[i]
        screen = (session.frames_dir / frame["file"]).read_text()
        render_png(normalize_frame(screen, meta["width"], frame["pointer"]), work / f"{i:05d}.png", work)

    with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
        list(pool.map(render, range(len(frames))))

    lines = []
    for i, frame in enumerate(frames):
        following = frames[i + 1]["t"] if i + 1 < len(frames) else end_time
        duration = min(max(following - frame["t"], 0.04), max_idle)
        if i + 1 == len(frames):
            duration = max(duration, end_hold)
        lines += [f"file '{work / f'{i:05d}.png'}'", f"duration {duration:.3f}"]
    lines.append(f"file '{work / f'{len(frames) - 1:05d}.png'}'")
    (work / "concat.txt").write_text("\n".join(lines) + "\n")
    # freeze renders at twice the size, which is more than a video needs.
    width, height = png_size(work / "00000.png")
    width, height = width // 4 * 2, height // 4 * 2
    result = subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(work / "concat.txt"),
         "-vf", f"scale={width}:{height}:force_original_aspect_ratio=decrease,pad={width}:{height},format=yuv420p",
         "-r", "30", "-c:v", "libx264", "-crf", "20", "-movflags", "+faststart", str(output)],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise Error(f"ffmpeg failed: {result.stderr.strip()}")
    return len(frames)


# Clipboard -------------------------------------------------------------------


def save_clipboard(session):
    if shutil.which("pbpaste"):
        data = subprocess.run(["pbpaste"], capture_output=True).stdout
        (session.dir / "clipboard").write_bytes(data)


def restore_clipboard(session):
    saved = session.dir / "clipboard"
    if saved.exists() and shutil.which("pbcopy"):
        subprocess.run(["pbcopy"], input=saved.read_bytes())


# Commands --------------------------------------------------------------------


def cmd_start(session, args):
    if session.exists():
        raise Error(f"session {session.name!r} already exists. Run `tui-record stop` or pick another --session")
    if not args.command:
        raise Error("give the command to run after --, for example `tui-record start -- htop`")
    size = re.fullmatch(r"(\d+)x(\d+)", args.size)
    if not size:
        raise Error("--size must look like 110x34")
    width, height = int(size[1]), int(size[2])
    session.tmux("kill-server", check=False)
    shutil.rmtree(session.dir, ignore_errors=True)
    session.dir.mkdir(parents=True)
    save_clipboard(session)
    command = shlex.join(args.command)
    # Options must be set before the pane exists. remain-on-exit keeps the
    # last screen around if the app exits.
    session.tmux(
        "start-server",
        ";", "set-option", "-g", "default-terminal", "tmux-256color",
        ";", "set-option", "-g", "status", "off",
        ";", "set-option", "-g", "remain-on-exit", "on",
        ";", "set-option", "-g", "extended-keys", "on",
        ";", "set-option", "-g", "extended-keys-format", "csi-u",
        ";", "new-session", "-d", "-s", "app", "-x", str(width), "-y", str(height),
        "-c", os.path.abspath(args.cwd), "-e", "COLORTERM=truecolor", command,
    )
    meta = {"width": width, "height": height, "command": command, "recorder_pid": None}
    if not args.no_record:
        log = open(session.dir / "recorder.log", "w")
        recorder = subprocess.Popen(
            [sys.executable, os.path.abspath(__file__), "--session", session.name, "_record"],
            stdout=log, stderr=log, stdin=subprocess.DEVNULL, start_new_session=True,
        )
        meta["recorder_pid"] = recorder.pid
    session.meta_path.write_text(json.dumps(meta))
    if args.wait_for:
        wait_for(session, args.wait_for, gone=False, timeout=args.timeout)
    print(f"started {session.name!r}: {command} ({width}x{height}{', not recording' if args.no_record else ''})")


def wait_for(session, text, gone, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        present = text in session.capture(ansi=False)
        if present != gone:
            return
        time.sleep(0.1)
    raise Error(f"timed out after {timeout}s waiting for {text!r} to {'disappear' if gone else 'appear'}")


def cmd_screen(session, args):
    session.meta()
    screen = session.capture(ansi=args.ansi).rstrip("\n")
    if args.numbered:
        screen = "\n".join(f"{i:3d}│{line}" for i, line in enumerate(screen.split("\n"), start=1))
    print(screen)


def cmd_find(session, args):
    session.meta()
    matches = find_text(session.capture(ansi=False), args.text)
    if not matches:
        raise Error(f"{args.text!r} is not on screen")
    for col, row, width in matches:
        print(f"{col},{row}" + (f" to {col + width - 1},{row}" if width > 1 else ""))


def cmd_type(session, args):
    session.meta()
    for char in args.text:
        session.send_literal(char)
        time.sleep(args.delay)


def cmd_key(session, args):
    session.meta()
    for key in args.keys:
        session.tmux("send-keys", "-t", "app", key)
        time.sleep(args.delay)


def cmd_move(session, args):
    session.meta()
    move_to(session, resolve(session, args.target, args.nth), args.steps)


def cmd_click(session, args):
    session.meta()
    point = resolve(session, args.target, args.nth)
    move_to(session, point, args.steps)
    button = BUTTONS[args.button]
    for _ in range(2 if args.double else 1):
        mouse_event(session, button, *point)
        mouse_event(session, button, *point, release=True, delay=0.08)


def cmd_drag(session, args):
    session.meta()
    start = resolve(session, args.start, args.nth, anchor="start")
    end = resolve(session, args.end, args.end_nth, anchor="end")
    move_to(session, start, args.steps)
    time.sleep(0.15)
    mouse_event(session, 0, *start)
    glide(session, 32, start, end, args.steps)
    mouse_event(session, 0, *end, release=True)


def cmd_scroll(session, args):
    meta = session.meta()
    if args.at:
        point = resolve(session, args.at)
        move_to(session, point, 1)
    else:
        point = session.pointer() or (meta["width"] // 2, meta["height"] // 2)
    code = 64 if args.direction == "up" else 65
    for _ in range(args.lines):
        mouse_event(session, code, *point, delay=0.05)


def cmd_wait(session, args):
    session.meta()
    wait_for(session, args.text, args.gone, args.timeout)


def cmd_screenshot(session, args):
    meta = session.meta()
    pointer = None if args.no_pointer else session.pointer()
    screen = session.capture(ansi=True)
    with tempfile.TemporaryDirectory() as work:
        render_png(normalize_frame(screen, meta["width"], pointer), Path(args.output).resolve(), work)
    print(f"wrote {args.output}")


def cmd_stop(session, args):
    meta = session.meta()
    stop_recorder(session, meta)
    session.tmux("kill-server", check=False)
    restore_clipboard(session)
    try:
        if args.output:
            if not meta.get("recorder_pid"):
                raise Error("this session was started with --no-record, so there is no video")
            count = render_video(session, meta, Path(args.output).resolve(), args.max_idle, args.end_hold)
            print(f"wrote {args.output} ({count} frames)")
    except Error:
        print(f"kept the frames in {session.dir}", file=sys.stderr)
        session.meta_path.rename(session.dir / "meta.stopped.json")
        raise
    if args.keep:
        session.meta_path.rename(session.dir / "meta.stopped.json")
        print(f"kept the frames in {session.dir}")
    else:
        shutil.rmtree(session.dir, ignore_errors=True)


def cmd_record(session, _args):
    record_loop(session)


def main():
    parser = argparse.ArgumentParser(
        prog="tui-record",
        description="Drive a terminal app in a private tmux server and record it as a video.",
        epilog="Targets are `col,row` (1-based) or text on the screen. "
        "Example: tui-record start -- pi; tui-record drag 'With chaining' 'bucket.'; tui-record stop -o demo.mp4",
    )
    parser.add_argument("--session", default=os.environ.get("TUI_RECORD_SESSION", "default"),
                        help="session name (default: $TUI_RECORD_SESSION or 'default')")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("start", help="start COMMAND in a new session and begin recording")
    p.add_argument("--size", default="110x34", help="terminal size as COLSxROWS (default: 110x34)")
    p.add_argument("--cwd", default=".", help="directory to run the command in")
    p.add_argument("--wait-for", metavar="TEXT", help="wait until TEXT is on screen before returning")
    p.add_argument("--timeout", type=float, default=15, help="seconds to wait for --wait-for (default: 15)")
    p.add_argument("--no-record", action="store_true", help="only take screenshots, no video")
    p.add_argument("command", nargs=argparse.REMAINDER, help="command to run, after --")
    p.set_defaults(func=cmd_start)

    p = sub.add_parser("screen", help="print the current screen")
    p.add_argument("--numbered", "-n", action="store_true", help="prefix each line with its row number")
    p.add_argument("--ansi", action="store_true", help="include colors and styles")
    p.set_defaults(func=cmd_screen)

    p = sub.add_parser("find", help="print the col,row of each match of TEXT")
    p.add_argument("text")
    p.set_defaults(func=cmd_find)

    p = sub.add_parser("type", help="type TEXT one character at a time")
    p.add_argument("text")
    p.add_argument("--delay", type=float, default=0.04, help="seconds between characters (default: 0.04)")
    p.set_defaults(func=cmd_type)

    p = sub.add_parser("key", help="press keys by tmux name: Enter, Escape, Tab, BSpace, Up, C-c, M-x, F1")
    p.add_argument("keys", nargs="+")
    p.add_argument("--delay", type=float, default=0.1, help="seconds between keys (default: 0.1)")
    p.set_defaults(func=cmd_key)

    for name, func, help_text in [("move", cmd_move, "move the pointer to TARGET"),
                                  ("click", cmd_click, "move to TARGET and click it")]:
        p = sub.add_parser(name, help=help_text)
        p.add_argument("target")
        p.add_argument("--nth", type=int, default=1, help="use the Nth match of a text target")
        p.add_argument("--steps", type=int, default=10, help="pointer steps on the way (default: 10)")
        if name == "click":
            p.add_argument("--button", choices=BUTTONS, default="left")
            p.add_argument("--double", action="store_true")
        p.set_defaults(func=func)

    p = sub.add_parser("drag", help="press at START, drag to END, release. Text START uses its first "
                       "character and text END its last, so this selects from START through END")
    p.add_argument("start")
    p.add_argument("end")
    p.add_argument("--nth", type=int, default=1, help="use the Nth match of START")
    p.add_argument("--end-nth", type=int, default=1, help="use the Nth match of END")
    p.add_argument("--steps", type=int, default=12, help="pointer steps on the way (default: 12)")
    p.set_defaults(func=cmd_drag)

    p = sub.add_parser("scroll", help="send mouse wheel events")
    p.add_argument("direction", choices=["up", "down"])
    p.add_argument("--lines", type=int, default=3, help="wheel events to send (default: 3)")
    p.add_argument("--at", metavar="TARGET", help="where to scroll (default: the pointer)")
    p.set_defaults(func=cmd_scroll)

    p = sub.add_parser("wait", help="wait until TEXT is on screen")
    p.add_argument("text")
    p.add_argument("--gone", action="store_true", help="wait until TEXT is no longer on screen")
    p.add_argument("--timeout", type=float, default=10, help="seconds (default: 10)")
    p.set_defaults(func=cmd_wait)

    p = sub.add_parser("screenshot", help="render the current screen to a PNG")
    p.add_argument("output")
    p.add_argument("--no-pointer", action="store_true", help="leave out the mouse pointer")
    p.set_defaults(func=cmd_screenshot)

    p = sub.add_parser("stop", help="stop the app and recording, and render the video with -o")
    p.add_argument("-o", "--output", help="write the recording to this .mp4")
    p.add_argument("--max-idle", type=float, default=2.0,
                   help="longest a frame may stay on screen, which cuts your pauses (default: 2)")
    p.add_argument("--end-hold", type=float, default=2.0, help="seconds to show the last frame (default: 2)")
    p.add_argument("--keep", action="store_true", help="keep the captured frames")
    p.set_defaults(func=cmd_stop)

    p = sub.add_parser("_record", help=argparse.SUPPRESS)
    p.set_defaults(func=cmd_record)

    args = parser.parse_args()
    if getattr(args, "command", None) and args.command[:1] == ["--"]:
        args.command = args.command[1:]
    try:
        args.func(Session(args.session), args)
    except Error as error:
        print(f"tui-record: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
