{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./sh.nix
    ./vcs.nix
    ./term.nix
    ./ripgrep.nix
  ];

  # Don't change this value, even when updating home-manager.
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    # enableFishIntegration = true;
    nix-direnv.enable = true;
  };

  programs.neovim = {
    enable = true;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    enableFishIntegration = true;
    settings = {
      enter_accept = false;
    };
  };

  programs.tmux = {
    enable = true;
    shell = "${pkgs.nushell}/bin/nu";
  };

  programs.zellij = {
    enable = true;
  };

  programs.aerc = {
    enable = true;
  };

  home.file = {
    ".bin".source = ./../../bin;
    ".config/balance/config.toml".source = ./../../balance/balance.toml;
    ".stylua.toml".source = ./../../stylua/stylua.toml;
    "Library/Preferences/aerc".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/code/config/aerc";
    ".config/ghostty".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/code/config/ghostty";
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/code/config/nvim";
    ".config/zellij".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/code/config/zellij";
    ".config/jjui".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/code/config/jjui";
  };

  home.activation.createFolders = ''
    mkdir -p ~/.config

    mkdir -p .config/cli
    touch .config/cli/history

    mkdir -p ~/Desktop/screenshots
    mkdir -p ~/code/dev-tools
  '';
}
