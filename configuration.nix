{ pkgs, ... }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    htop
    neovim
    eza
    bat
    rustup
    # nerd-fonts.iosevka
    atlas
    jq
    curl
    wget
    google-cloud-sdk

    # lun
    google-alloydb-auth-proxy

    # typescript
    prettierd

    # go
    gotools
    golines
    oapi-codegen
    mockgen
    golangci-lint
    delve

    # TODO
    # postgresql
    # nodejs_22, couldn't get `npm install` or `rush install` working
    # nvm
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
  ];

  # Required because I installed Determinate nix, not vanilla
  nix.enable = false;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
};
