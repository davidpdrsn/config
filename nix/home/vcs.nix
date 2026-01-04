{...}: {
  programs.git = {
    enable = true;
    lfs = {
      enable = true;
    };
    ignores = [
      "*.swp"
      "*.blend1"
      ".DS_Store"
      "/tags"
      ".sass-cache"
      "xterm-256color.ti"
      "screen-256color.ti"
      "tags.lock"
      "tags.temp"
      "target"
      "result"
      "rusty-tags.vi"
      ".metals"
      ".bloop"
      ".jvmopts"
      ".bsp"
      "project/project/"
      ".vim"
      "dump.rdb"
      "/tmp"
      "bacon.toml"
      ".reload-on-demand.toml"
      ".temp"
      ".tmp"
      "__debug_bin*"
      ".direnv"
      ".claude"
      ".cache"
      ".jj"
    ];
    settings = {
      alias = {
        wt = "worktree";
      };
      user = {
        name = "David Pedersen";
        email = "david.pdrsn@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };
      push = {
        autoSetupRemote = "true";
      };
      "filter \"lfs\"" = {
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = "true";
        clean = "git-lfs clean -- %f";
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      line-numbers = true;
      side-by-side = false;
    };
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        email = "david.pdrsn@gmail.com";
        name = "David Pedersen";
      };
      ui = {
        default-command = ["log"];
        pager = ":builtin";
        diff-editor = ":builtin";
      };
      snapshot = {
        auto-update-stale = true;
      };
      colors = {
        "diff token" = {underline = false;};
        "diff removed token" = {bg = "#221111";};
        "diff added token" = {bg = "#002200";};
        "log commit change_id shortest" = "green";
      };
      template-aliases = {
        "format_short_signature(signature)" = "";
        "in_branch(commit)" = "commit.contained_in(\"immutable_heads()..bookmarks()\")";
      };
      aliases = {
        c = ["commit"];
        n = ["new"];
        rb = ["rebase"];
        sync = ["util" "exec" "--" "jj-sync"];
        desc-ai = ["util" "exec" "--" "jj-desc-ai"];
        dai = ["util" "exec" "--" "jj-desc-ai"];
        blame = ["file" "annotate"];
        integrate = ["squash" "-A" "main" "-B" "merge" "-f"];
      };
      revset-aliases = {
        "siblings(x)" = "children(parents(x)) ~ x";
        "merge" = "description(exact:\"merge\n\")";
      };
      git = {
        # Prevent pushing work in progress, anything explicitly labeled "private", or the mega merge commit
        private-commits = "description(glob:'✨ai✨*') | description(glob:'wip:*') | description(glob:'private:*') | description(exact:\"merge\n\")";
      };
      templates = {
        git_push_bookmark = "\"david/jj-\" ++ change_id. short()";
        draft_commit_description = ''
          concat(
            coalesce(description, default_commit_description, "\n"),
            surround(
              "\nJJ: This commit contains the following changes:\n", "",
              indent("JJ:     ", diff.stat(72)),
            ),
            "\nJJ: ignore-rest\n",
            diff.git(),
          )
        '';
        log_node = ''
          if(self && !current_working_copy && !immutable && !conflict && in_branch(self),
            "◇",
            builtin_log_node
          )
        '';
      };
    };
  };
}
