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
    # ...
  in
  {
    darwinConfigurations."Davids-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit inputs self; };

      modules = [
        ./configuration.nix
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
