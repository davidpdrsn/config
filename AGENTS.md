# Config

Personal nix configuration using flakes.

## Commands

- `just check` - Validate the flake structure
- `just build` - Build the system configuration without activating (no sudo required)
- `just switch` - Build and apply changes (requires sudo)
- `just test` - Run tests (opencode plugin tests)

## Important

Always run `just test` after making changes.

Always run `just check && just build` after making changes to nix files.
