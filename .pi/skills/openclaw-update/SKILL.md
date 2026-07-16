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

### Verify model changes against the runtime

`openclaw models status --plain` reports the configured default, not necessarily
the model held by an already-running, pre-warmed Codex runtime. After changing
the default model:

1. Restart the gateway rather than relying only on config hot reload:

```bash
ssh hetzner-2 'openclaw gateway restart'
```

2. Run a real, non-delivered test turn with a fresh session ID (change the ID on
each run):

```bash
ssh hetzner-2 'openclaw agent --session-id model-verification-1 --message "Reply with exactly OK." --json'
```

The request consumes tokens and creates a session. Verify these response fields:

- `result.meta.agentMeta.model`
- `result.meta.executionTrace.winnerModel`
- `result.meta.executionTrace.fallbackUsed`

The configured model and both runtime model fields should agree, and
`fallbackUsed` should be `false`. For channel conversations such as Telegram,
start a new session with `/new` after the gateway restart; existing sessions may
retain their previous model.

## If CLI is newer than gateway service

1. Inspect and fix stale/invalid config keys:

```bash
ssh hetzner-2 'openclaw doctor'
ssh hetzner-2 'openclaw doctor --fix'
```

`doctor --fix` mutates OpenClaw state and configuration and may disable skills
whose dependencies are unavailable. Review its output and preserve its backup.

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

If startup migrations repeatedly fail with `canonical plugin state changed`,
`doctor --fix` may intentionally leave a conflicting legacy Codex sidecar in
place rather than overwrite newer canonical state. Review the exact path from
the warning, rename that legacy sidecar to a timestamped backup, restart the
gateway, and verify connectivity. Never delete the sidecar without preserving
a backup.

## Safety

- Do not print or share gateway token values.
- Keep deployment user-driven (do not auto-deploy unless explicitly requested).
