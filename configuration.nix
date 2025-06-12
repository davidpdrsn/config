{ self, pkgs, ... }:

let
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
    git-lfs
    tree
    dust
    typos
    dotnet-sdk_9
    csharpier

    # docker
    colima
    docker
    docker-compose

    # lun
    google-cloud-sdk
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
    (pkgs.callPackage ./go/oapi_codegen.nix {})
    (pkgs.callPackage ./go/sqlboiler.nix {})
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;
    dataDir = "/Users/davidpdrsn/.nix-services/postgresql-17";
  };

  environment.variables = {
    # https://www.reddit.com/r/godot/comments/1f0tswq/comment/ljwyvnk/
    DOTNET_ROOT = "${pkgs.dotnet-sdk_9}/share/dotnet";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
  };
}
