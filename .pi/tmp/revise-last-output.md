Perfect — staying in plan mode.

Here’s a sharper implementation plan for `pi/plugins/cloud.ts` to eliminate the extra `hetzner-1` git remote and use only `origin` for code transfer.

## Goal

Keep SSH host as `hetzner-1`, but stop creating/maintaining a second VCS remote.  
Use:

- local: `jj git push --remote origin ...`
- remote server: clone/fetch from GitHub (`origin` URL)
- still sync local-only artifacts via rsync/scp (`.env`, session files)

---

## Planned edits

### A) Constants and naming cleanup
- Keep:
  - `const HOST = "hetzner-1";`
- Remove:
  - `const REMOTE_NAME = "hetzner-1";`
- Add:
  - `const GIT_REMOTE_NAME = "origin";` (optional, for readability)

---

### B) Remove remote bare-repo bootstrap
Delete logic tied to:

- `remoteBareRepo = ~/.cloud-remotes/<repo>.git`
- remote `git init --bare`
- local `jj git remote list/add/set-url hetzner-1`

Keep only remote prep needed for runtime:

- workspace parent dirs
- placeholder file for sanitized session paths

---

### C) Push bookmark to origin
Replace current push step with:

- `jj git push --remote origin --allow-private --allow-empty-description --named cloud/<changeId>=@`

No extra local remote manipulation required.

---

### D) Resolve origin URL and clone on server
Add a step to read local origin URL (from local repo), then use it on remote:

- `git remote get-url origin` (or `jj git remote list` parse fallback)
- fail fast if missing/empty

Then on server:

- `jj git clone <originUrl> <remoteWorkspace> -b <bookmarkName>`

This preserves the current workspace-per-session model.

---

### E) Keep local-only file transfer as-is
No behavior change:

- `.env` rsync if present
- session chain rewrite/scp (including absolute-path sanitization)

This is the “rsync as necessary” part and should remain.

---

### F) Update messaging
Change user-facing strings that mention pulling from `hetzner-1` remote:

- from: `jj git fetch --remote hetzner-1`
- to: `jj git fetch --remote origin`

Everything else can remain largely unchanged.

---

## Validation plan

After implementation:

1. `just test`
2. (No nix files touched, so no mandatory `just check && just build` required for this change)

---

## Risks to account for

1. **Server auth to GitHub**  
   Remote host must have credentials (SSH key/token) to clone origin.

2. **Origin URL compatibility**  
   If local origin URL is not usable from server context, clone may fail.  
   (Could later add optional override URL if needed.)

3. **Cloud bookmark accumulation on GitHub**  
   `cloud/<changeId>` refs can pile up; optional cleanup can be added later.

---

If you want, I can make this change exactly in one patch once you send `go`.