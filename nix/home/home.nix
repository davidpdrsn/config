{config, ...}: {
  imports = [
    ./sh.nix
    ./ssh.nix
    ./vcs.nix
    ./ripgrep.nix
    ./tmux.nix
    ./pi-agent.nix
    ../lib/pi-agent.nix
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
    ".config/opencode".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/opencode";
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/claude/settings.json";
    ".codex/config.toml".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/codex/config.toml";
    ".config/vmux".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/vmux";
    ".ssh/known_hosts_hetzner".text = ''
      hetzner-1 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDTrvqqopEOL+XGqbsQugUqaKOBx7foziysoB7oIMUnr
      46.225.16.43 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDTrvqqopEOL+XGqbsQugUqaKOBx7foziysoB7oIMUnr
      hetzner-2 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnytj8FmLxKn36zdZjWFbcaJyLrqTBm/C1zEqtbWah6
      46.225.17.37 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnytj8FmLxKn36zdZjWFbcaJyLrqTBm/C1zEqtbWah6
    '';
  };

  home.activation.createFolders = ''
    mkdir -p ~/.config

    mkdir -p .config/cli
    touch .config/cli/history
  '';
}
