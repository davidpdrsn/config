---
name: openclaw-update
description: "Update OpenClaw in this repo via the llm-agents flake input, validate changes, and verify/fix hetzner-2 gateway service version mismatches."
---

# openclaw-update

Use this skill when updating OpenClaw in this repository, especially for `hetzner-2` runtime.

## When to use

- You want a newer OpenClaw release in this repo.
- `openclaw --version` differs from `openclaw-gateway.service` version on `hetzner-2`.

## Source of truth

OpenClaw is sourced from flake input `llm-agents` and consumed as:

- `inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openclaw`

Primary runtime usage in this repo:

- `nix/machines/hetzner-2/configuration.nix` (`openclawCli` and `openclawPackages`)

## Update procedure

1. Update only the OpenClaw source input:

```bash
nix flake update llm-agents --no-warn-dirty --flake .
```

Alternative interactive route:

```bash
./scripts/nix-update-input
# then select: llm-agents
```

2. Validate repository state:

```bash
just check && just build
just test
```

3. Deploy (user executes manually):

```bash
just switch-vps-2
# optionally:
just switch-vps-1
```

## Post-deploy verification (hetzner-2)

```bash
ssh hetzner-2 'openclaw --version'
ssh hetzner-2 'systemctl --user cat openclaw-gateway.service | rg -n "openclaw-[0-9]"'
ssh hetzner-2 'systemctl --user status openclaw-gateway.service --no-pager -l | head -n 40'
```

CLI and service should report the same OpenClaw version.

## If CLI is newer than gateway service

1. Fix stale/invalid config keys:

```bash
ssh hetzner-2 'openclaw doctor --fix'
```

2. Reinstall gateway service from current CLI:

```bash
ssh hetzner-2 'openclaw gateway install --force'
```

3. Restart gateway service:

```bash
ssh hetzner-2 'openclaw gateway restart'
```

4. Re-check versions with the verification commands above.

## Troubleshooting

If restart/install fails, inspect service logs:

```bash
ssh hetzner-2 'journalctl --user -u openclaw-gateway.service -n 100 --no-pager'
```

## Safety

- Do not print or share gateway token values.
- Keep deployment user-driven (do not auto-deploy unless explicitly requested).
