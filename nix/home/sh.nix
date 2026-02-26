{
  lib,
  pkgs,
  config,
  ...
}: {
  home.sessionPath =
    (lib.optionals pkgs.stdenv.isLinux [
      "/run/wrappers/bin"
    ])
    ++ [
      "/run/current-system/sw/bin"
      "${config.home.homeDirectory}/.cargo/bin"
      "${config.home.homeDirectory}/.bin"
    ];

  home.sessionVariables = {
    EDITOR = "nvim";
    SHELL = "${config.home.profileDirectory}/bin/fish";

    TERM = "tmux-256color";

    CARGO_PROFILE_DEV_SPLIT_DEBUGINFO = "unpacked";
    CARGO_PROFILE_TEST_SPLIT_DEBUGINFO = "unpacked";
    CARGO_INCREMENTAL = 1;
    CARGO_TERM_COLOR = "always";
  };

  programs.fish = {
    enable = true;
    generateCompletions = true;
    shellAliases = {
      v = "nvim";
      l = "eza --long --header --git --all --sort name";
      la = "eza -a --long --header --sort name";
      ".." = "z ..";
      cd = "z";
      c = "clear";
      ca = "cargo";
      cat = "bat";
      dt = "cd ~/Desktop";
      diff = "diff --color";
      oc = "opencode";
      p = "pi";

      j = "jjui";
      jc = "jj commit";
      jd = "jj desc";
      jn = "jj new";
      jb = "jj bookmark";
      jp = "jj git push --all";
      jf = "jj git fetch";
      jpll = "jj git pull";

      gaa = "git add --all";
      gap = "git add -p";
      gb = "git branch";
      gc = "git commit --verbose";
      gco = "git checkout";
      gcob = "git checkout -b";
      gcof = "git-branch-picker checkout";
      gmf = "git-branch-picker merge";
      git-cargo-lock-conflict = "git checkout main -- Cargo.lock";
      gl = "git log --graph --decorate --oneline -20";
      gll = "git log --graph --decorate --oneline";
      gp = "git push";
      gpf = "git push --force-with-lease";
      gd = "git diff";
      d = "git diff";
      gdc = "git diff --cached";
      gr = "git reset";
      grh = "git reset --hard";
      grs = "git reset --soft";
      gca = "git commit --amend --verbose";
      gpll = "git pull";
      ga = "git add";
      grb = "git rebase";
      gm = "git merge";
      grbc = "git rebase --continue";
      grba = "git rebase --abort";
      grbi = "git rebase -i";
      gs = "git show";
      xtask = "cargo xtask";
      b = "t build";
      r = "t run";
      at = "tmux attach";
      dbui = "nvim +DBUI";
      claude-json = "claude --print --output-format json";
      claude-yolo = "claude --dangerously-skip-permissions";
      vi = "nvim";
      vim = "nvim";
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      format = lib.concatStrings [
        "$hostname"
        "$directory"
        "\${custom.git_prompt}"
        "$line_break"
        "$character"
      ];
      custom = {
        git_prompt = {
          command = "git-prompt";
          format = "$output";
          when = true;
        };
        jj_current_operation = {
          command = "jj-current-operation";
          format = "[$output]($style)";
          when = true;
          detect_files = [".jj"];
          style = "yellow";
        };
      };
      hostname = {
        ssh_only = true;
        format = "[$hostname]($style) ";
        style = "bold yellow";
      };
      directory = {
        fish_style_pwd_dir_length = 1;
        style = "white";
      };
      nix_shell = {
        format = "[$name]($style)";
      };
      rust = {
        format = "[$symbol($version)]($style)";
      };
      golang = {
        format = "[$symbol($version)]($style)";
      };
      nodejs = {
        format = "[$symbol($version)]($style)";
      };
    };
  };
}
