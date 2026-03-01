{pkgs}:
pkgs.writeShellApplication {
  name = "agent-status";
  runtimeInputs = [
    pkgs.bun
    pkgs.coreutils
  ];
  text = ''
    set -euo pipefail

    repo_root="''${AGENT_STATUS_REPO:-$HOME/config}"
    pi_dir="$repo_root/pi"

    if [ ! -f "$pi_dir/scripts/agent-status.ts" ]; then
      echo "agent-status: script not found at $pi_dir/scripts/agent-status.ts" >&2
      echo "Set AGENT_STATUS_REPO to your config repo root if needed." >&2
      exit 1
    fi

    exec bun --cwd "$pi_dir" "$pi_dir/scripts/agent-status.ts" "$@"
  '';
}
