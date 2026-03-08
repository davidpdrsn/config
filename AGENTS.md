# Config

Personal nix configuration using flakes.

## Commands

- `just check` - Validate the flake structure
- `just build` - Build the system configuration without activating (no sudo required)
- `just switch` - Build and apply changes (requires sudo)
- `just test` - Install opencode JS deps and run extension tests

## Important

Always run `just test` after making changes.

`just test` bootstraps `opencode` dependencies via `bun install --cwd opencode --frozen-lockfile`.

Always run `just check && just build` after making changes to nix files.

_Never_ run `just switch` or similar commands. The human will do that.

When running into configuration issues, never run random commands to try and fix it. Always consider if there is a way to change the nix configuration to make it work.
