inputs @ {
  self,
  pkgs,
  ...
}: let
in {
  # Required because I installed Determinate nix, not vanilla
  nix.enable = false;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  system.primaryUser = "davidpdrsn";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # general
    htop
    neovim
    eza
    bat
    rustup
    jq
    curl
    wget
    postgresql
    gh
    fzf
    fd
    tree
    dust
    procs
    hyperfine
    cargo-watch
    tokei
    cargo-limit
    alejandra
    stylua

    amp-cli
    claude-code

    # docker
    colima
    docker
    docker-compose

    # gui apps
    code-cursor
    blender
    obsidian
    slack
    spotify
    keymapp
    unnaturalscrollwheels
    google-chrome
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;
    dataDir = "/Users/davidpdrsn/.nix-services/postgresql-17";
  };
}
