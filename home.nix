{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./nix/sh.nix
    ./nix/vcs.nix
    ./nix/term.nix
    ./nix/ripgrep.nix
    ./nix/aerospace.nix
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

  programs.zellij = {
    enable = true;
  };

  programs.neovim = {
    enable = true;
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/.bin"
  ];

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
    extraConfig = builtins.readFile ./tmux/tmux.conf;
  };

  home.file = {
    ".bin".source = ./bin;
    ".config/balance/config.toml".source = ./balance/balance.toml;
    ".config/zellij/config.kdl".source = ./zellij/config.kdl;
    ".stylua.toml".source = ./stylua/stylua.toml;
  };

  home.activation.createFolders = ''
    mkdir -p ~/.config

    mkdir -p .config/cli
    touch .config/cli/history

    if [ ! -e ~/.config/nvim ]; then
      ln -s ~/config/nvim ~/.config
    fi

    if [ ! -e ~/.config/ghostty ]; then
      ln -s ~/config/ghostty ~/.config
    fi

    mkdir -p ~/Desktop/screenshots
    mkdir -p ~/code/dev-tools
  '';
}
