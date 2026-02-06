# Config

Personal nix-darwin configuration using flakes.

## Commands

- `make check` - Validate the flake structure
- `make build` - Build the system configuration without activating (no sudo required)
- `make switch` - Build and apply changes (requires sudo)

## Important

Always run `make check && make build` after making changes to nix files.
