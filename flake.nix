{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    configuration = { pkgs, ... }: {
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

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#Davids-MacBook-Pro
    darwinConfigurations."Davids-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        home-manager.darwinModules.home-manager
        {
          users.users.davidpdrsn.home = "/Users/davidpdrsn";
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.davidpdrsn = import ./home.nix;
        }
      ];
    };
  };
}
