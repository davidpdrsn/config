{
  lib,
  pkgs,
  config,
  ...
}: {
  home.sessionPath =
    (lib.optionals pkgs.stdenv.hostPlatform.isLinux [
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
  };

  # fish is the shell, but tools still start zsh. Without any zsh startup file it stops at
  # zsh-newuser-install's first-run menu.
  home.file.".zshrc".text = "";

  programs.fish = {
    enable = true;
    generateCompletions = true;
    interactiveShellInit = ''
      set -g fish_greeting
    '';
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
      p = "pi";

      b = "/Users/davidpdrsn/code/gitbutler/gitbutler-git/target/release/but";
      bt = "/Users/davidpdrsn/code/gitbutler/gitbutler-git/target/release/but tui";

      gaa = "git add --all";
      gb = "git branch";
      gc = "git commit --verbose";
      gco = "git checkout";
      gcof = "git-branch-picker checkout";
      gl = "git log --graph --decorate --oneline -20";
      gll = "git log --graph --decorate --oneline";
      gla = "git log --graph --decorate --oneline --all";
      gp = "git push";
      gpf = "git push --force-with-lease";
      gd = "git diff";
      d = "git diff";
      gdc = "git diff --cached";
      gr = "git reset";
      grh = "git reset --hard";
      gca = "git commit --amend --verbose";
      gpll = "git pull";
      ga = "git add";
      grb = "git rebase";
      grbc = "git rebase --continue";
      grbi = "git rebase -i";
      r = "t run";
      cc = "claude --dangerously-skip-permissions";
      vi = "nvim";
      vim = "nvim";
      te = "run-most-recent-cargo-test";
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
        "$line_break"
        "$character"
      ];
      hostname = {
        ssh_only = lib.mkDefault true;
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
      nodejs = {
        format = "[$symbol($version)]($style)";
      };
    };
  };
}
