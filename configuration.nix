{ self, pkgs, ... }:

let
  oapi_codegen = pkgs.callPackage ./oapi_codegen.nix {};
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
    redis

    # docker
    colima
    docker
    docker-compose

    # lun
    google-alloydb-auth-proxy

    # typescript
    prettierd

    # go
    gotools
    golines
    delve
    atlas # v0.34.0, requires v0.32.0
    mockgen
    golangci-lint
    oapi_codegen
    # go install github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.13.4
    # go install github.com/volatiletech/sqlboiler/v4@v4.14.2
    # go install github.com/volatiletech/sqlboiler/v4/drivers/sqlboiler-psql@v4.14.2

    # TODO
    # nodejs_22, couldn't get `npm install` or `rush install` working
    # nvm
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
