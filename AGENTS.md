# Config

Personal nix configuration using flakes.

## Commands

- `just check` - Validate the flake structure
- `just build` - Build the system configuration without activating (no sudo required)
- `just switch` - Build and apply changes (requires sudo)

## Important

Always run `just check && just build` after making changes to nix files.
