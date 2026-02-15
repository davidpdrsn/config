{
  description = "Personal multi-machine nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # home-manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # homebrew (macOS only)
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    # personal dev tools (all public repos)
    jjui.url = "github:davidpdrsn/jjui";
    jjui.inputs.nixpkgs.follows = "nixpkgs";

    gh-notifications.url = "git+ssh://git@github.com/davidpdrsn/gh-notifications.git?ref=main";
    gh-notifications.inputs.nixpkgs.follows = "nixpkgs";

    opencode.url = "github:anomalyco/opencode?ref=refs/tags/v1.1.63";
    opencode.inputs.nixpkgs.follows = "nixpkgs";

    # other dev tools managed via `make clone-dev-tools` + cargo install
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
    # Common arguments passed to all system and home-manager modules
    commonArgs = {
      inherit inputs self;
      username = "davidpdrsn";
      shell = "fish";
    };

    # Build a home-manager config block with shared base + machine-specific overrides.
    # Usage: mkHomeManagerConfig [ ./nix/machines/<machine>/home.nix ]
    mkHomeManagerConfig = extraModules: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${commonArgs.username} = {
        imports = [./nix/home/home.nix] ++ extraModules;
      };
      home-manager.extraSpecialArgs = commonArgs;
    };
  in {
    # ── macOS (MacBook Pro) ──────────────────────────────────────────
    darwinConfigurations."Davids-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      specialArgs = commonArgs;

      modules = [
        ./nix/machines/macbook-pro/configuration.nix

        {users.users.${commonArgs.username}.home = "/Users/${commonArgs.username}";}

        home-manager.darwinModules.home-manager
        (mkHomeManagerConfig [./nix/machines/macbook-pro/home.nix])

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

    # ── NixOS (Hetzner VPS) ─────────────────────────────────────────
    nixosConfigurations."nix-4gb-nbg1-1" = nixpkgs.lib.nixosSystem {
      specialArgs = commonArgs;

      modules = [
        ./nix/machines/hetzner/configuration.nix

        home-manager.nixosModules.home-manager
        (mkHomeManagerConfig [./nix/machines/hetzner/home.nix])
      ];
    };
  };
}
