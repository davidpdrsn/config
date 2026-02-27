{pkgs}:
pkgs.writeShellApplication {
  name = "cloud-agent";
  text = ''
    set -euo pipefail

    if [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
      cat <<'EOF'
Usage:
  cloud-agent <prompt>

Starts a cloud Pi agent by invoking Pi's /cloud command in print mode.
On success, prints only the tmux attach command to stdout.
EOF
      exit 0
    fi

    prompt="$*"
    if [ -z "$prompt" ]; then
      prompt="continue"
    fi

    exec pi -p "/cloud $prompt"
  '';
}
