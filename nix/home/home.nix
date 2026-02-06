{config, ...}: {
  imports = [
    ./sh.nix
    ./ssh.nix
    ./vcs.nix
    ./ripgrep.nix
    ./tmux.nix
  ];

  # Don't change this value, even when updating home-manager.
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.neovim = {
    enable = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      enter_accept = false;
    };
  };

  home.file = {
    ".bin".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/bin";
    ".stylua.toml".source = ./../../stylua/stylua.toml;
    ".config/ghostty".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/ghostty";
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/nvim";
    ".config/jjui".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/jjui";
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/claude/settings.json";
  };

  home.activation.createFolders = ''
    mkdir -p ~/.config

    mkdir -p .config/cli
    touch .config/cli/history
  '';
}
