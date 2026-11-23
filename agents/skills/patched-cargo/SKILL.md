---
name: patched-cargo
description: "Use when asked to make a Rust project use the patched cargo, the cargo fork in ~/code/cargo that garbage collects target dirs, or to check or fix whether a project uses it"
---

# Patched cargo

`~/code/cargo` is a fork of cargo that garbage collects build directories. Every build marks the units it uses by setting their directories' modification time, and units unused for `cache.target-clean.max-age` are removed. `~/.cargo/config.toml` sets that to 4 days. `~/code/cargo/FORK.md` explains how the fork is maintained.

`home.nix` links `~/.local/share/patched-cargo/bin/cargo` to `~/code/cargo/target/release/cargo`. A direnv wrapper puts that directory on `PATH`, but only in the directories listed in `patchedCargoDirs` in `~/config/nix/machines/macbook-pro/home.nix`, and only when the project's `.envrc` runs `use flake`. Turning the fork on for a project means adding it to that list. The project itself only needs an `.envrc` that runs `use flake`.

## Add a project

1. Check that the project's `.envrc` contains `use flake` or `use flake <path>`. The wrapper hooks `use_flake`, so other `.envrc` setups don't get the patched cargo. If there is no `.envrc` but there is a `flake.nix` with a dev shell, create `.envrc` with `use flake`. If the repo shouldn't track it, add `.envrc` and `.direnv/` to `.git/info/exclude`, then run `direnv allow` for the `.envrc` you created.
2. Check the project's rustc with `direnv exec <dir> rustc --version`. If the `.envrc` is blocked, `nix eval` on the flake's dev shell shows the toolchain instead. The fork is cargo 1.100, based on upstream's `rust-1.100.0` branch, and FORK.md describes the risk of version skew with an old rustc. rustc 1.98.1 and 1.100.0 work. For an older rustc, build the project once with `~/.local/share/patched-cargo/bin/cargo` in its dev shell. If that works, add the project anyway, and ask the user whether to move it to a newer Rust. Don't change the project's Rust without asking. The preferred setup is rust-overlay's `rust-bin.stable.latest.default` with `rust-src` and `rust-analyzer`, as `~/code/foreverapp/flake.nix` does. A newer rustc changes every unit hash, so the next build is a full rebuild.
3. Add the project's directory, relative to the home directory, to `patchedCargoDirs` in `~/config/nix/machines/macbook-pro/home.nix`. An entry covers everything below it. For a repo with worktrees elsewhere, also add the directory that holds the worktrees, such as `.gitbutler-worktrees/<repo>`.
4. In `~/config`, run `just check && just build`. Commit the change on a new branch with a descriptive name, for example `but commit -b patched-cargo-<project> -m "..." nix/machines/macbook-pro/home.nix`. Without `-b`, `but` makes up a branch name.
5. Ask the user to run `just switch` in `~/config`. It needs `sudo` with a password, so you can't run it. Until it runs, direnv uses the old list.

## Check that it works

```sh
direnv exec <dir> /bin/sh -c 'command -v cargo'
```

This must print `/Users/davidpdrsn/.local/share/patched-cargo/bin/cargo`. If it prints a nix store path, the directory isn't in the active `patchedCargoDirs`, either because it's missing from the list or because `just switch` hasn't run. If direnv says the `.envrc` is blocked, ask the user to run `direnv allow` in that directory. Don't allow an `.envrc` you didn't write. A shell that was already in the directory before `just switch` needs `direnv reload`.

The Target GC app (`/Applications/Target GC.app`, source in `~/code/cargo/target-gc-app`) runs the same check. After a refresh, its sidebar shows a green dot for projects that use the fork.

## The first build

A build with the patched cargo registers the target dir in `~/.cargo/target-gc/build-dirs`. Cleaning requires a `CACHEDIR.TAG` in the target dir. Cargo writes the tag only when it creates the dir, so the fork also writes a missing tag when the dir has lock files from earlier builds.

Cleaning runs after a successful build, at most once a day, for every registered target dir. To clean one target dir now with the configured max age, run the fork's binary by its path. That also works for a project that doesn't use the fork, where `cargo` is stock cargo, which has no `--build-dir`:

```sh
cd <project> && ~/.local/share/patched-cargo/bin/cargo clean gc -Zgc --build-dir "$PWD/target"
```

Add `--dry-run` to see what it would remove. Pass `--max-target-age "<N> days"` to use another age. Run it from the project so that cargo reads the project's config. Use `du -sk target` before and after to measure what it freed. Cargo's "Removed ... total" counts each hard-linked file separately, so it can overstate the space freed. The GC only removes from `build/`, `incremental/`, `deps/` and `.fingerprint/` in each profile dir. The final binaries and libraries in `target/<profile>/` stay until a `cargo clean`.

Artifacts from stock cargo before 1.100 use the legacy layout (`deps/`, `.fingerprint/`). The fork removes them once their modification time is older than the max age, without tracking their use.

## Turn it off

Remove the directory from `patchedCargoDirs` and have the user run `just switch`. To turn off the fork everywhere, delete `~/code/cargo/target/release/cargo`. The link then dangles, and `PATH` lookup finds the flake's cargo.
