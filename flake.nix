{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # home-manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # homebrew
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    # private repos requires /etc/nix/nix.custom.conf with gh personal access token (classic)
    # token is in Passwords.app under "GitHub nix-darwin access token"

    # personal dev tools
    smart-pwd-2.url = "github:davidpdrsn/smart-pwd-2";
    is-vim-running.url = "github:davidpdrsn/is-vim-running";
    git-prompt.url = "github:davidpdrsn/git-prompt";
    git-remove-merged-branches.url = "github:davidpdrsn/git-remove-merged-branches";
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
    home-manager,
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
    ...
  }: let
    # ...
  in {
    darwinConfigurations."Davids-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      specialArgs = {inherit inputs self;};

      modules = [
        ./configuration.nix

        home-manager.darwinModules.home-manager
        {
          users.users.davidpdrsn.home = "/Users/davidpdrsn";
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.davidpdrsn = import ./home.nix;
        }

        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = false;
            user = "davidpdrsn";
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };
            mutableTaps = false;
          };
        }
      ];
    };
  };
}
