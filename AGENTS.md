# Config

Personal nix configuration using flakes.

## Commands

- `just check` - Validate the flake structure
- `just build` - Build the system configuration without activating (no sudo required)
- `just switch` - Build and apply changes (requires sudo)

## Important

Always run `just check && just build` after making changes to nix files.

When running into configuration issues, never run random commands to try and fix it. Always consider if there is a way to change the nix configuration to make it work.

Never manually copy nix files onto the servers. Use the normal deployment workflow.
