{
  pkgs,
  openclawCli,
  username,
}: let
  repo = "/home/${username}/obsidian-vaults";
  stateDir = "/home/${username}/.local/state/obsidian-vaults-pull";

  pullScript = pkgs.writeShellApplication {
    name = "obsidian-vaults-pull";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      openclawCli
    ];
    text = ''
      set -euo pipefail

      repo='${repo}'
      state_dir='${stateDir}'
      state_file="$state_dir/last-status"

      mkdir -p "$state_dir"

      old_status=""
      if [ -f "$state_file" ]; then
        old_status="$(<"$state_file")"
      fi

      new_status="ok"
      message=""
      max_attempts=3

      notify() {
        local text="$1"
        openclaw message send \
          --channel telegram \
          --target 8355979215 \
          --message "$text" >/dev/null 2>&1 || true
      }

      fail() {
        local status="$1"
        local text="$2"
        new_status="$status"
        message="$text"
      }

      if [ ! -d "$repo" ]; then
        fail "path_missing" "Obsidian pull failed: $repo does not exist"
      fi

      if [ "$new_status" = "ok" ] && ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        fail "not_git_repo" "Obsidian pull failed: $repo is not a git repository"
      fi

      branch=""
      if [ "$new_status" = "ok" ]; then
        branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD || true)"
      fi
      if [ "$new_status" = "ok" ] && [ -z "$branch" ]; then
        fail "detached_head" "Obsidian pull failed: repository is in detached HEAD"
      fi

      upstream=""
      if [ "$new_status" = "ok" ] && ! upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null)"; then
        fail "missing_upstream" "Obsidian pull failed: branch '$branch' has no upstream"
      fi

      result=""
      if [ "$new_status" = "ok" ]; then
        attempt=1
        while [ "$attempt" -le "$max_attempts" ]; do
          git -C "$repo" add -A

          if ! git -C "$repo" diff --cached --quiet; then
            timestamp="$(date '+%Y-%m-%d %H:%M')"
            commit_message="chore(obsidian): auto-sync server $timestamp"
            if ! commit_output="$(git -C "$repo" commit -m "$commit_message" 2>&1)"; then
              fail "commit_failed" "Obsidian sync failed on $branch ($upstream): commit failed: $commit_output"
              break
            fi
          fi

          if ! pull_output="$(git -C "$repo" pull --rebase origin "$branch" 2>&1)"; then
            git -C "$repo" rebase --abort >/dev/null 2>&1 || true
            fail "rebase_failed" "Obsidian sync failed on $branch ($upstream): rebase failed: $pull_output"
            break
          fi

          if push_output="$(git -C "$repo" push origin "$branch" 2>&1)"; then
            result="pull: $pull_output | push: $push_output"
            break
          fi

          case "$push_output" in
            *"non-fast-forward"*|*"fetch first"*|*"[rejected]"*)
              attempt=$((attempt + 1))
              if [ "$attempt" -gt "$max_attempts" ]; then
                fail "push_rejected" "Obsidian sync failed on $branch ($upstream): push rejected after $max_attempts attempts: $push_output"
              fi
              ;;
            *)
              fail "push_failed" "Obsidian sync failed on $branch ($upstream): push failed: $push_output"
              ;;
          esac

          if [ "$new_status" != "ok" ]; then
            break
          fi
        done
      fi

      if [ "$new_status" = "ok" ] && [ "$old_status" != "ok" ] && [ -n "$old_status" ]; then
        notify "Obsidian pull recovered on $branch ($upstream)."
      fi

      if [ "$new_status" != "ok" ] && [ "$new_status" != "$old_status" ]; then
        notify "$message"
      fi

      if [ "$new_status" != "$old_status" ]; then
        printf '%s\n' "$new_status" >"$state_file"
      fi

      if [ "$new_status" != "ok" ]; then
        echo "$message" >&2
        exit 1
      fi

      echo "Obsidian sync succeeded on $branch ($upstream): $result"
    '';
  };
in {
  service = {
    description = "Pull Obsidian vault repository";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      ExecStart = "${pkgs.lib.getExe pullScript}";
    };
  };

  timer = {
    description = "Run Obsidian vault pull every 30 minutes";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*:0/30";
      Persistent = true;
      Unit = "obsidian-vaults-pull.service";
    };
  };
}
