{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Latest nixpkgs for packages with pending updates (e.g., jujutsu)
    nixpkgs-latest.url = "github:NixOS/nixpkgs/master";

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

    # nix version manager for finding specific versions of packages
    nxv.url = "github:jamesbrink/nxv";

    # private repos requires /etc/nix/nix.custom.conf with gh personal access token (classic)
    # token is in Passwords.app under "GitHub nix-darwin access token"

    # personal dev tools
    smart-pwd-2.url = "github:davidpdrsn/smart-pwd-2";
    is-vim-running.url = "github:davidpdrsn/is-vim-running";
    git-prompt.url = "github:davidpdrsn/git-prompt";
    git-remove-merged-branches.url = "github:davidpdrsn/git-remove-merged-branches";
    replace.url = "github:davidpdrsn/replace";
    git-branch-picker.url = "github:davidpdrsn/git-branch-picker";
    remove-indentation.url = "github:davidpdrsn/remove-indentation";
    go-insert-error.url = "github:davidpdrsn/go-insert-error/b4aff99d348f1ba1a1d24c0c9c1447e4a5939a65";
    git-history-csv.url = "git+file:///Users/davidpdrsn/code/git-history-csv?rev=8f7a6add93577bf3f0fce1ddc35e4cb0fc4122fe";

    # other dev tools not in nix:
    # - test-command
    # - parse-dotenv
    # - git-diff-ai-summarize
    # - format-prettier
    # - build-proxy
    # - cli
    # - balance
    # - jj-sync-prs
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
    home-manager,
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
    nxv,
    ...
  }: let
    # Common arguments for both systems
    commonArgs = {
      inherit inputs self;
      username = "davidpdrsn";
      shell = "fish";
    };

    homeManagerConfig = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.davidpdrsn = import ./nix/home/home.nix;
      home-manager.extraSpecialArgs = commonArgs;
    };
  in {
    darwinConfigurations."Davids-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      specialArgs = commonArgs;

      modules = [
        ./nix/machines/macbook-pro/configuration.nix

        {users.users.${commonArgs.username}.home = "/Users/${commonArgs.username}";}

        home-manager.darwinModules.home-manager
        homeManagerConfig

        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = false;
            user = commonArgs.username;
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
