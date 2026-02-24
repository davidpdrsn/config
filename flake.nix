{
  description = "Personal multi-machine nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

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

    jjui.url = "github:davidpdrsn/jjui";
    jjui.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";

    # other dev tools managed via `make clone-dev-tools` + cargo install
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
    flake-utils,
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
  in
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bun
            oxlint
            typescript-language-server
            just
            fzf
            git
            inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
          ];
        };
      }
      // nixpkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
        apps.darwin-rebuild = {
          type = "app";
          program = "${nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";
        };
      })
    // {
      # ── macOS (MacBook Pro) ──────────────────────────────────────────
      darwinConfigurations."macos" = nix-darwin.lib.darwinSystem {
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
          ./nix/machines/hetzner-1/configuration.nix

          home-manager.nixosModules.home-manager
          (mkHomeManagerConfig [./nix/machines/hetzner/home.nix])
        ];
      };

      nixosConfigurations."nix-4gb-nbg1-2" = nixpkgs.lib.nixosSystem {
        specialArgs = commonArgs;

        modules = [
          ./nix/machines/hetzner-2/configuration.nix

          home-manager.nixosModules.home-manager
          (mkHomeManagerConfig [./nix/machines/hetzner/home.nix])
        ];
      };
    };
}
