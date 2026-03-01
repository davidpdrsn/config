---
name: trolley
description: "Use for projects with trolley.toml to bundle/package/install TUIs, especially macOS app packaging and runtime pitfalls."
---

# trolley Skill

Use this skill whenever a repo contains `trolley.toml` or the user asks about `trolley init`, `trolley run`, `trolley package`, `.app` creation, or app installation.

## Preflight

1. Confirm Trolley is available:

```bash
trolley -h
```

2. Confirm project has a manifest:

```bash
ls trolley.toml
```

3. Read current config before edits:
- `trolley.toml`
- `justfile` (if present)

## Safe defaults for this environment

### Packaging on macOS

`dmg` currently fails in this environment due to `create-dmg` TLS backend issues.

Use:

```bash
trolley package --formats mac-app,archive
```

Not:

```bash
trolley package
```

unless explicitly asked to debug DMG.

### TUI subcommand apps

If the app needs a subcommand (e.g. `gh-pr tui`), prefer building a dedicated launcher binary and letting Trolley keep its default command.

Pattern:

- Add `cmd/<app>-tui/main.go` that calls CLI with args `["tui"]`.
- Build platform binaries from that launcher.
- Point `trolley.toml` `[macos.binaries]` to those launcher binaries.
- Avoid custom `[ghostty].command` when possible.

Reason: custom command overrides are more fragile across run vs packaged app layouts.

## macOS install workflow (recommended)

1. Build launcher binaries (if applicable).
2. Package with `--formats mac-app,archive`.
3. Copy app to `/Applications`.
4. Validate launch from `/Applications`.

Example just targets:

```just
trolley-build:
    CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o bin/app-tui-darwin-arm64 ./cmd/app-tui
    CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o bin/app-tui-darwin-amd64 ./cmd/app-tui

trolley-package: trolley-build
    trolley package --formats mac-app,archive

install: trolley-package
    rm -rf "/Applications/MyApp.app"
    ditto "trolley/build/<identifier>/aarch64-macos/dist/MyApp.app" "/Applications/MyApp.app"
```

## Known runtime pitfall: `gh` not found in app

GUI-launched apps may not inherit shell PATH.

Symptom:
- `exec: "gh": executable file not found in $PATH`

Fix in `trolley.toml`:

```toml
[environment]
variables = { PATH = "/Users/davidpdrsn/.nix-profile/bin:/etc/profiles/per-user/davidpdrsn/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" }
```

Then re-package/re-install.

## Known runtime pitfall: `Requested executable not found`

Symptom in packaged `.app` window:
- `Requested executable not found. Please verify the command is on the PATH and try again.`

Checks:

```bash
ls -la /Applications/<App>.app/Contents/MacOS
read /Applications/<App>.app/Contents/Resources/ghostty.conf
```

If the default relative command fails after install, patch to absolute executable path as a pragmatic workaround:

```conf
command = direct:/Applications/<App>.app/Contents/MacOS/<slug>_core
```

## Verification checklist after changes

- `trolley package --formats mac-app,archive` succeeds.
- Dist contains:
  - `.../dist/<name>.app`
  - `.../dist/<slug>-<version>-aarch64-macos.tar.gz`
- Installed app resources include expected `environment` and `ghostty.conf`.
- Launching `/Applications/<App>.app` starts both runtime and core processes.

## Communication style

When applying trolley fixes, summarize:
- what changed (`trolley.toml`, `justfile`, launcher binary),
- why (dmg/TLS, PATH, command resolution),
- exact verification performed.
