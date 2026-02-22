# Default: show recipe picker
default:
    @just --list --unsorted | tail -n +2 | awk '{print $1}' | grep -v '^default$' | fzf --no-sort | xargs -r just || true

# Build and apply changes (requires sudo)
switch:
    #!/usr/bin/env bash
    if [ "$(uname)" = "Darwin" ]; then
        sudo darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"
    else
        sudo nixos-rebuild switch --flake ".#$(hostname)"
    fi

# Build the system configuration without activating (no sudo required)
build:
    #!/usr/bin/env bash
    if [ "$(uname)" = "Darwin" ]; then
        darwin-rebuild build --flake ".#$(scutil --get LocalHostName)"
    else
        nixos-rebuild build --flake ".#$(hostname)"
    fi

# Validate the flake structure
check:
    nix flake check

# Run plugin tests
test:
    oxlint --deny-warnings opencode/plugins
    bun test --cwd opencode
    bunx tsc --noEmit --project opencode/tsconfig.json

# Update a flake input (interactive picker)
update:
    ./scripts/nix-update-input
    just switch

# Update opencode to latest GitHub release tag
update-opencode:
    ./scripts/nix-update-opencode
    just switch

# Compare available updates
compare-updates:
    ./scripts/nix-compare-updates

# Clone personal dev tool repos
clone-dev-tools:
    ./scripts/clone-dev-tools

# Regenerate clone script from local dev-tools repos
update-clone-dev-tools:
    ./scripts/update-clone-dev-tools

# SSH into Hetzner VPS 2
ssh:
    ssh hetzner-2

# SSH into Hetzner VPS 1
ssh-1:
    ssh hetzner-1

# SSH into Hetzner VPS 2
ssh-2:
    ssh hetzner-2

# Deploy latest config to VPS 1
switch-vps-1:
    ./scripts/deploy-vps 1

# Deploy latest config to VPS 2
switch-vps-2:
    ./scripts/deploy-vps 2
