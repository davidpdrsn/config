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

# Compare available updates
compare-updates:
    ./scripts/nix-compare-updates

# Clone personal dev tool repos
clone-dev-tools:
    ./scripts/clone-dev-tools

# SSH into the Hetzner VPS
ssh:
    ssh hetzner-nixos

# Deploy latest config to VPS
switch-vps:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check that @ is empty (no uncommitted changes)
    if [ -n "$(jj diff --summary)" ]; then
        echo "error: working copy (@) is not empty" >&2
        exit 1
    fi

    # Check that @- is main
    main_id=$(jj log -r "main" --no-graph -T 'commit_id')
    parent_id=$(jj log -r "@-" --no-graph -T 'commit_id')
    if [ "$main_id" != "$parent_id" ]; then
        echo "error: @- is not main" >&2
        exit 1
    fi

    # Check that main is pushed to origin
    origin_id=$(jj log -r "main@origin" --no-graph -T 'commit_id')
    if [ "$main_id" != "$origin_id" ]; then
        echo "error: main is not pushed to origin" >&2
        exit 1
    fi

    ssh -t hetzner-nixos 'cd /home/davidpdrsn/config && jj git fetch && jj new main && /run/wrappers/bin/sudo nixos-rebuild switch --flake ".#$(hostname)"'
