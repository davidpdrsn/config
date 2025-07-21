{...}: {
  programs.git = {
    enable = true;
    aliases = {
      wt = "worktree";
    };
    extraConfig = {
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
    delta = {
      enable = true;
      options = {
        line-numbers = true;
        side-by-side = false;
      };
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
        default-command = "log";
        pager = ":builtin";
      };
      colors = {
        "diff token" = {underline = false;};
        "diff removed token" = {bg = "#221111";};
        "diff added token" = {bg = "#002200";};
        "log commit change_id shortest" = "green";
      };
      "template-aliases" = {
        "format_short_signature(signature)" = "";
        "format_short_commit_id(id)" = "id.shortest()";
        "format_short_change_id(id)" = "id.shortest()";
        "format_timestamp(timestamp)" = "";
      };
      templates = {
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
      };
    };
  };
}
