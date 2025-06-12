{ config, pkgs, ... }:

{
  home.username = "davidpdrsn";
  home.homeDirectory = "/Users/davidpdrsn";

  # Don't change this value, even when updating home-manager.
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    htop
    neovim
    eza
    bat
    rustup
  ];
  
  programs.git = {
    enable = true;
    includes = [{ path = "~/config/git/gitconfig"; }];
  };
  
  programs.zsh = {
    enable = true;
    initContent = builtins.readFile ./zsh/zshrc;
    autosuggestion = {
      enable = true;
    };
    syntaxHighlighting = {
      enable = true;
    };
  };
  
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    tmux = {
      enableShellIntegration = true;
    };
  };

  programs.tmux = {
    enable = true;
    # extraConfig = builtins.readFile ./tmux/tmux.conf
  };
  
  programs.ripgrep = {
    enable = true;
    arguments = [
      # Search hidden files / directories (e.g. dotfiles) by default
      "--hidden"
      # Search files in .gitignore
      "--no-ignore"
      # Using glob patterns to include/exclude files or folders
      "--glob=!.git/*"
      "--glob=!node_modules"
      "--glob=!.godot/*"
      "--glob=!build"
      "--glob=!builds"
      "--glob=!.cache"
      "--glob=!temp"
      "--glob=!*\.map"
      "--glob=!target"
      "--glob=!*\.log"
      "--glob=!*\.DS_Store"
      # Because who cares about case!?
      "--smart-case"
    ];
  };
  
  programs.zoxide.enable = true;
  programs.fd.enable = true;

  home.file = {
    ".gitignoreglobal".source = ./gitignoreglobal;
    ".config/ghostty".source = ./ghostty;
  };

  programs.home-manager.enable = true;
}
