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

  vendorHash = "sha256-/z5l+tgQuYBZ0A99A8CoTuqTSfnM52R43ppFrooRgOM=";
  doCheck = false;
}
