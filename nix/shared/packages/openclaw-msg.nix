{pkgs}:
pkgs.writeShellApplication {
  name = "openclaw-msg";
  runtimeInputs = [
    pkgs.openssh
    pkgs.coreutils
  ];
  text = ''
    set -euo pipefail

    host="''${OPENCLAW_MSG_HOST:-46.225.17.37}"
    user="''${OPENCLAW_MSG_USER:-davidpdrsn}"
    target="''${OPENCLAW_MSG_TARGET:-8355979215}"
    known_hosts="''${OPENCLAW_MSG_KNOWN_HOSTS:-$HOME/.ssh/known_hosts_hetzner}"

    identity="''${OPENCLAW_MSG_IDENTITY:-}"
    if [ -z "$identity" ]; then
      if [ -f "$HOME/.ssh/hetzner-to-hetzner-2" ]; then
        identity="$HOME/.ssh/hetzner-to-hetzner-2"
      elif [ -f "$HOME/.ssh/hetzner" ]; then
        identity="$HOME/.ssh/hetzner"
      fi
    fi

    usage() {
      cat <<'EOF'
Usage:
  openclaw-msg "message text"
  echo "message text" | openclaw-msg

Environment overrides:
  OPENCLAW_MSG_HOST         SSH host/IP that runs openclaw (default: 46.225.17.37)
  OPENCLAW_MSG_USER         SSH user (default: davidpdrsn)
  OPENCLAW_MSG_TARGET       Telegram target/chat id (default: 8355979215)
  OPENCLAW_MSG_IDENTITY     SSH private key path (auto-detected if unset)
  OPENCLAW_MSG_KNOWN_HOSTS  known_hosts file (default: ~/.ssh/known_hosts_hetzner)
EOF
    }

    if [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
      usage
      exit 0
    fi

    message=""
    if [ "$#" -gt 0 ]; then
      message="$*"
    elif [ ! -t 0 ]; then
      message="$(cat)"
    fi

    if [ -z "$message" ]; then
      usage >&2
      exit 1
    fi

    if [ ! -f "$known_hosts" ]; then
      echo "openclaw-msg: known_hosts file not found: $known_hosts" >&2
      exit 1
    fi

    if [ -n "$identity" ] && [ ! -f "$identity" ]; then
      echo "openclaw-msg: identity file not found: $identity" >&2
      exit 1
    fi

    ssh_args=(
      -F /dev/null
      -o BatchMode=yes
      -o ConnectTimeout=10
      -o StrictHostKeyChecking=yes
      -o UserKnownHostsFile="$known_hosts"
      -o IdentitiesOnly=yes
      -l "$user"
    )

    if [ -n "$identity" ]; then
      ssh_args+=( -i "$identity" )
    fi

    case "$target" in
      ""|*[!A-Za-z0-9@+._:-]*)
        echo "openclaw-msg: invalid OPENCLAW_MSG_TARGET: $target" >&2
        exit 1
        ;;
    esac

    remote_cmd="/bin/sh -c 'msg=\$(cat); openclaw agent --channel telegram --to \"$target\" --message \"\$msg\" --deliver'"

    # shellcheck disable=SC2029
    printf '%s' "$message" | ssh "''${ssh_args[@]}" "$host" "$remote_cmd"
  '';
}
