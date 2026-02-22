{pkgs, ...}: {
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
      "target/"
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
      ".claude/settings.local.json"
      ".cache"
      ".jj"
      ".go"
      ".worktrees"
    ];
    settings = {
      credential.helper = "!${pkgs.gh}/bin/gh auth git-credential";
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
      rebase = {
        updateRefs = true;
      };
      rerere = {
        enabled = true;
      };
      fetch = {
        prune = true;
      };
      merge = {
        conflictStyle = "zdiff3";
      };
      diff = {
        algorithm = "histogram";
      };
      commit = {
        verbose = true;
      };
      branch = {
        sort = "-committerdate";
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

  programs.jujutsu = let
    private-revset = "description(glob:'ai*') | description(glob:'wip:*') | description(glob:'private:*') | description(glob:'megamerge*')";
  in {
    enable = true;
    settings = {
      user = {
        email = "david.pdrsn@gmail.com";
        name = "David Pedersen";
      };
      ui = {
        default-command = ["log"];
        diff-editor = ":builtin";
        pager = "delta";
        diff-formatter = [
          "bash"
          "-c"
          "delta --width $width $left $right --features=split-view || true"
        ];
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
        blame = ["file" "annotate"];
        # decribe change using ai
        desc-ai = ["util" "exec" "--" "jj-desc-ai"];
        # integrate changes into a mega merge
        integrate = [
          "rebase"
          "-A"
          "trunk()"
          "-B"
          "merge"
          "-r"
        ];
        restack = [
          "util"
          "exec"
          "--"
          "bash"
          "-c"
          "jj simplify-parents && jj restack-inner"
        ];
        # rebase all changes on top of trunk
        restack-inner = [
          "rebase"
          "-s"
          "roots(trunk()..) & mutable()"
          "-o"
          "trunk()"
        ];
        # squash all ai commits
        squash-ai = [
          "squash"
          "--from"
          "mutable() & description(glob:'ai*') & ::@"
          "--into"
          "roots(mutable() & description(glob:'ai*') & ::@)"
          "--use-destination-message"
        ];
      };
      revset-aliases = {
        "siblings(x)" = "children(parents(x)) ~ x";
        "merge" = "description(glob:'megamerge*')";
      };
      git = {
        # Prevent pushing work in progress, anything explicitly labeled "private", or the mega merge commit
        private-commits = private-revset;
      };
      templates = {
        git_push_bookmark = "\"dp/jj-\" ++ change_id. short()";
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
            if(self && !current_working_copy && !immutable && !conflict && self.contained_in("${private-revset}"),
              "∴",
              builtin_log_node
            )
          )
        '';
      };
    };
  };
}
