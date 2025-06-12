{ self, pkgs, ... }:

let
  oapi_codegen = pkgs.callPackage ./go/oapi_codegen.nix {};
  sqlboiler = pkgs.callPackage ./go/sqlboiler.nix {};
in
{
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

  environment.systemPackages = with pkgs; [
    htop
    neovim
    eza
    bat
    rustup
    jq
    curl
    wget
    google-cloud-sdk
    postgresql
    gh

    # docker
    colima
    docker
    docker-compose

    # lun
    google-alloydb-auth-proxy

    # typescript
    prettierd
    # nodejs_22, couldn't get `npm install` or `rush install` working
    # nvm

    # go
    gotools
    golines
    delve
    atlas
    mockgen
    golangci-lint
    oapi_codegen
    sqlboiler
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
