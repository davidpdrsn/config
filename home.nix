{pkgs, config, ...}: {
  imports = [
    ./nix/sh.nix
    ./nix/vcs.nix
    ./nix/term.nix
    ./nix/ripgrep.nix
    ./nix/aerospace.nix
    ./nix/zellij.nix
  ];

  # Don't change this value, even when updating home-manager.
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  programs.neovim = {
    enable = true;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    settings = {
      enter_accept = false;
    };
  };

  programs.tmux = {
    enable = true;
    shell = "${pkgs.nushell}/bin/nu";
  };

  home.file = {
    ".bin".source = ./bin;
    ".config/balance/config.toml".source = ./balance/balance.toml;
    ".stylua.toml".source = ./stylua/stylua.toml;
    ".config/ghostty".source = config.lib.file.mkOutOfStoreSymlink ./ghostty;
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink ./nvim;
  };

  home.activation.createFolders = ''
    mkdir -p ~/.config

    mkdir -p .config/cli
    touch .config/cli/history

    mkdir -p ~/Desktop/screenshots
    mkdir -p ~/code/dev-tools
  '';
}
