You’re right — I jumped ahead. Thanks for calling it out.

### 1) Why harden command execution?
Given your current direction, **we don’t need to prioritize this now**.

I suggested it because shell-string spawning (`shell: true` + interpolated path/editor string) can be brittle and can mis-handle quoting/paths. But if the focus is just getting `/revise` reliable for your setup, this is optional cleanup, not required.

### 2) “Factor editor logic into helpers”
Agreed — **not useful now** if we’re not expanding plugin complexity. We can skip it.

### 6) “Consistent state + file handling”
This is the one that still makes sense:
- keep a stable temp path (`.pi/tmp/revise-last-output.md`)
- handle mkdir/write/read failures gracefully
- always fall back to loading original text into draft when file ops fail

I’ll stick strictly to that scope next, with no extra refactors.