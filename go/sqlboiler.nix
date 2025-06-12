{ pkgs ? import <nixpkgs> {} }:

pkgs.buildGoModule rec {
  pname = "sqlboiler";
  version = "4.14.2";

  src = pkgs.fetchFromGitHub {
    owner = "volatiletech";
    repo = "sqlboiler";
    rev = "v${version}";
    hash = "sha256-d3SML1cm+daYU5dEuwSXSsKwsJHxGuOEbwCvYfsMcFI=";
  };

  # The Go module lives in the 'v4' subdirectory of the repo.
  # We need to tell buildGoModule where to find the go.mod file.
  sourceRoot = "${src.name}/v4";

  # This is the hash of all the Go dependencies for the module.
  vendorHash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
}
