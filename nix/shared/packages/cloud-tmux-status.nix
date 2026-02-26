{pkgs}:
pkgs.writeShellApplication {
  name = "cloud-tmux-status";
  runtimeInputs = [
    pkgs.openssh
    pkgs.tmux
    pkgs.jq
    pkgs.ripgrep
    pkgs.gnugrep
    pkgs.gawk
    pkgs.coreutils
  ];
  text = ''
    set -euo pipefail

    host="''${CLOUD_TMUX_STATUS_HOST:-46.225.16.43}"
    user="''${CLOUD_TMUX_STATUS_USER:-davidpdrsn}"
    known_hosts="''${CLOUD_TMUX_STATUS_KNOWN_HOSTS:-$HOME/.ssh/known_hosts_hetzner}"
    identity="''${CLOUD_TMUX_STATUS_IDENTITY:-}"
    lines="''${CLOUD_TMUX_STATUS_LINES:-300}"
    pattern="''${CLOUD_TMUX_STATUS_PATTERN:-^pi-cloud-}"
    include_pane="false"
    format="json"

    usage() {
      cat <<'EOF'
Usage:
  cloud-tmux-status [options]

Inspect remote cloud tmux sessions and summarize status.

Options:
  --host <host>       SSH host/IP to inspect (default: 46.225.16.43)
  --user <user>       SSH user (default: davidpdrsn)
  --identity <path>   SSH private key path
  --known-hosts <p>   known_hosts file (default: ~/.ssh/known_hosts_hetzner)
  --lines <n>         Lines to capture from each pane (default: 300)
  --pattern <regex>   Session name regex filter (default: ^pi-cloud-)
  --json              Output JSON (default)
  --table             Output a compact table
  --include-pane      Include full pane text in JSON (debugging)
  -h, --help          Show help

Environment:
  CLOUD_TMUX_STATUS_HOST
  CLOUD_TMUX_STATUS_USER
  CLOUD_TMUX_STATUS_IDENTITY
  CLOUD_TMUX_STATUS_KNOWN_HOSTS
  CLOUD_TMUX_STATUS_LINES
  CLOUD_TMUX_STATUS_PATTERN
EOF
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --host)
          host="$2"
          shift 2
          ;;
        --user)
          user="$2"
          shift 2
          ;;
        --identity)
          identity="$2"
          shift 2
          ;;
        --known-hosts)
          known_hosts="$2"
          shift 2
          ;;
        --lines)
          lines="$2"
          shift 2
          ;;
        --pattern)
          pattern="$2"
          shift 2
          ;;
        --json)
          format="json"
          shift
          ;;
        --table)
          format="table"
          shift
          ;;
        --include-pane)
          include_pane="true"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          echo "cloud-tmux-status: unknown option: $1" >&2
          usage >&2
          exit 1
          ;;
      esac
    done

    if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
      echo "cloud-tmux-status: --lines must be an integer" >&2
      exit 1
    fi

    if [ -z "$identity" ]; then
      if [ -f "$HOME/.ssh/hetzner-to-hetzner-1" ]; then
        identity="$HOME/.ssh/hetzner-to-hetzner-1"
      elif [ -f "$HOME/.ssh/hetzner" ]; then
        identity="$HOME/.ssh/hetzner"
      fi
    fi

    if [ ! -f "$known_hosts" ]; then
      echo "cloud-tmux-status: known_hosts file not found: $known_hosts" >&2
      exit 1
    fi

    if [ -n "$identity" ] && [ ! -f "$identity" ]; then
      echo "cloud-tmux-status: identity file not found: $identity" >&2
      exit 1
    fi

    q() {
      printf '%s' "$(printf '%s' "$1" | jq -Rr @sh)"
    }

    run_ssh() {
      local script="$1"
      local -a ssh_args=(
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
      printf '%s\n' "$script" | ssh "''${ssh_args[@]}" "$host" bash -s --
    }

    list_script='set -euo pipefail
if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not found on remote host" >&2
  exit 2
fi
tmux list-sessions -F "#{session_name}" 2>/dev/null || true'

    all_sessions_raw="$(run_ssh "$list_script")"
    mapfile -t all_sessions <<< "$all_sessions_raw"

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    idx=0
    for session in "''${all_sessions[@]}"; do
      [ -n "$session" ] || continue
      if ! printf '%s\n' "$session" | rg -q -- "$pattern"; then
        continue
      fi

      pane_target_script="set -euo pipefail
TARGET=\"\$(tmux list-panes -t $(q "$session") -F '#{session_name}:#{window_index}.#{pane_index}' | head -n1)\"
printf '%s' \"\$TARGET\""
      target="$(run_ssh "$pane_target_script" || true)"

      pane=""
      if [ -n "$target" ]; then
        capture_script="set -euo pipefail
tmux capture-pane -p -J -t $(q "$target") -S -$lines || true"
        pane="$(run_ssh "$capture_script" || true)"
      fi

      pane_recent="$(printf '%s\n' "$pane" | tail -n 120)"

      status_raw="$(printf '%s\n' "$pane_recent" | rg -N '^Status:' | tail -n1 | sed -E 's/^Status:[[:space:]]*//' || true)"
      bookmark="$(printf '%s\n' "$pane_recent" | rg -N '^Bookmark:' | tail -n1 | sed -E 's/^Bookmark:[[:space:]]*//' || true)"
      workspace="$(printf '%s\n' "$pane_recent" | rg -N '^Workspace:' | tail -n1 | sed -E 's/^Workspace:[[:space:]]*//' || true)"
      follow_up="$(printf '%s\n' "$pane_recent" | rg -N '^Follow-up:' | tail -n1 | sed -E 's/^Follow-up:[[:space:]]*//' || true)"

      summary_json="$({
        printf '%s\n' "$pane_recent" |
          awk '
            /^Summary:[[:space:]]*$/ {in_summary=1; next}
            /^Status:[[:space:]]*/ {in_summary=0}
            in_summary && /^- / {
              sub(/^- /, "", $0)
              print
            }
          '
      } | jq -Rsc 'split("\n") | map(select(length > 0))')"

      state="unknown"
      status_lower="$(printf '%s' "$status_raw" | tr '[:upper:]' '[:lower:]')"

      if [ -n "$status_lower" ]; then
        case "$status_lower" in
          done*) state="done" ;;
          partial*) state="partial" ;;
          blocked*) state="blocked" ;;
          failed*) state="failed" ;;
        esac
      fi

      if [ "$state" = "unknown" ] && printf '%s\n' "$pane_recent" | rg -q '✅ Cloud run complete'; then
        state="done"
      fi

      if [ "$state" = "unknown" ] && printf '%s\n' "$pane_recent" | rg -q '/cloud failed:'; then
        state="failed"
      fi

      if [ "$state" = "unknown" ] && [ -n "$target" ]; then
        state="running"
      fi

      last_line="$(printf '%s\n' "$pane_recent" | awk 'NF && $0 !~ /^[[:space:]]*[↑↓]/ && $0 !~ /gpt-[0-9]/ {last=$0} END {print last}')"
      if [ -z "$last_line" ]; then
        last_line="$(printf '%s\n' "$pane_recent" | awk 'NF {last=$0} END {print last}')"
      fi

      if [ "$include_pane" = "true" ]; then
        jq -n \
          --arg session "$session" \
          --arg target "$target" \
          --arg state "$state" \
          --arg status "$status_raw" \
          --arg bookmark "$bookmark" \
          --arg workspace "$workspace" \
          --arg followUp "$follow_up" \
          --arg lastLine "$last_line" \
          --arg pane "$pane_recent" \
          --argjson summary "$summary_json" \
          '{
            session: $session,
            target: (if $target == "" then null else $target end),
            state: $state,
            status: (if $status == "" then null else $status end),
            bookmark: (if $bookmark == "" then null else $bookmark end),
            workspace: (if $workspace == "" then null else $workspace end),
            followUp: (if $followUp == "" then null else $followUp end),
            summary: $summary,
            lastLine: (if $lastLine == "" then null else $lastLine end),
            pane: $pane
          }' > "$tmp_dir/$idx.json"
      else
        jq -n \
          --arg session "$session" \
          --arg target "$target" \
          --arg state "$state" \
          --arg status "$status_raw" \
          --arg bookmark "$bookmark" \
          --arg workspace "$workspace" \
          --arg followUp "$follow_up" \
          --arg lastLine "$last_line" \
          --argjson summary "$summary_json" \
          '{
            session: $session,
            target: (if $target == "" then null else $target end),
            state: $state,
            status: (if $status == "" then null else $status end),
            bookmark: (if $bookmark == "" then null else $bookmark end),
            workspace: (if $workspace == "" then null else $workspace end),
            followUp: (if $followUp == "" then null else $followUp end),
            summary: $summary,
            lastLine: (if $lastLine == "" then null else $lastLine end)
          }' > "$tmp_dir/$idx.json"
      fi

      idx=$((idx + 1))
    done

    sessions_json="$(if [ "$idx" -eq 0 ]; then printf '[]'; else jq -s '.' "$tmp_dir"/*.json; fi)"

    output_json="$(jq -n \
      --arg host "$host" \
      --arg pattern "$pattern" \
      --arg generatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson includePane "$(if [ "$include_pane" = "true" ]; then echo true; else echo false; fi)" \
      --argjson sessions "$sessions_json" \
      '{
        host: $host,
        pattern: $pattern,
        generatedAt: $generatedAt,
        includePane: $includePane,
        sessions: $sessions,
        counts: {
          total: ($sessions | length),
          running: ($sessions | map(select(.state == "running")) | length),
          done: ($sessions | map(select(.state == "done")) | length),
          partial: ($sessions | map(select(.state == "partial")) | length),
          blocked: ($sessions | map(select(.state == "blocked")) | length),
          failed: ($sessions | map(select(.state == "failed")) | length),
          unknown: ($sessions | map(select(.state == "unknown")) | length)
        }
      }')"

    if [ "$format" = "json" ]; then
      printf '%s\n' "$output_json"
      exit 0
    fi

    printf 'host: %s\n' "$host"
    printf 'pattern: %s\n' "$pattern"
    printf '\n'

    printf '%-42s  %-8s  %-18s  %s\n' "SESSION" "STATE" "STATUS" "BOOKMARK"
    printf '%-42s  %-8s  %-18s  %s\n' "------------------------------------------" "--------" "------------------" "----------------"
    printf '%s\n' "$output_json" | jq -r '.sessions[] | [
      .session,
      .state,
      (.status // ""),
      (.bookmark // "")
    ] | @tsv' | while IFS=$'\t' read -r s st status bookmark; do
      printf '%-42s  %-8s  %-18s  %s\n' "$s" "$st" "$status" "$bookmark"
    done
  '';
}
