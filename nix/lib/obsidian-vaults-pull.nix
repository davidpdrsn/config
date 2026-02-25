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

      if [ "$new_status" = "ok" ] && [ -n "$(git -C "$repo" status --porcelain)" ]; then
        fail "dirty_worktree" "Obsidian pull skipped: local changes detected in $repo"
      fi

      upstream=""
      if [ "$new_status" = "ok" ] && ! upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null)"; then
        fail "missing_upstream" "Obsidian pull failed: branch '$branch' has no upstream"
      fi

      pull_output=""
      if [ "$new_status" = "ok" ] && ! pull_output="$(git -C "$repo" pull --ff-only 2>&1)"; then
        fail "pull_failed" "Obsidian pull failed on $branch ($upstream): $pull_output"
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

      echo "Obsidian pull succeeded: $pull_output"
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
