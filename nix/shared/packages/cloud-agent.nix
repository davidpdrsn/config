{pkgs}:
pkgs.writeShellApplication {
  name = "cloud-agent";
  runtimeInputs = [
    pkgs.bun
    pkgs.coreutils
  ];
  text = ''
    set -euo pipefail

    repo_root="''${CLOUD_AGENT_REPO:-$HOME/config}"
    pi_dir="$repo_root/pi"

    if [ ! -f "$pi_dir/scripts/cloud-agent.ts" ]; then
      echo "cloud-agent: script not found at $pi_dir/scripts/cloud-agent.ts" >&2
      echo "Set CLOUD_AGENT_REPO to your config repo root if needed." >&2
      exit 1
    fi

    exec bun --cwd "$pi_dir" "$pi_dir/scripts/cloud-agent.ts" "$@"
  '';
}
