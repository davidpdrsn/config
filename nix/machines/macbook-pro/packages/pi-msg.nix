{pkgs}:
pkgs.writeShellApplication {
  name = "pi-msg";
  runtimeInputs = [
    pkgs.bun
    pkgs.coreutils
  ];
  text = ''
    set -euo pipefail

    repo_root="''${PI_MSG_REPO:-$HOME/config}"
    pi_dir="$repo_root/pi"

    if [ ! -f "$pi_dir/scripts/pi-msg.ts" ]; then
      echo "pi-msg: script not found at $pi_dir/scripts/pi-msg.ts" >&2
      echo "Set PI_MSG_REPO to your config repo root if needed." >&2
      exit 1
    fi

    export PI_MSG_CALLER_CWD="$PWD"
    exec bun --cwd "$pi_dir" "$pi_dir/scripts/pi-msg.ts" "$@"
  '';
}
