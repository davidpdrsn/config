{
  description = "A flake for building a Rust binary";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system}.default = pkgs.rustPlatform.buildRustPackage rec {
        pname = "build-proxy";
        # version = "13.0.0";

        src = pkgs.fetchFromGitHub {
          owner = "davidpdrsn";
          repo = "build-proxy";
          rev = "93e06c09b5c1ebfa623d02a3808a415fd0ad6811";
          sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };

        cargoLock.lockFile = ./Cargo.lock;
        postUnpack = "cp ${src}/Cargo.lock ./Cargo.lock";
      };
    };
}
