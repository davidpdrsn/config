{ pkgs ? import <nixpkgs> {} }:

pkgs.buildGoModule rec {
  pname = "oapi-codegen";
  version = "1.13.4";

  src = pkgs.fetchFromGitHub {
    # https://github.com/oapi-codegen/oapi-codegen
    owner = "oapi-codegen";
    repo = "oapi-codegen";
    rev = "v${version}";
    hash = "sha256-9uHgc2q3ZNM0hQsAY+1RLAH3NfcV+dQo+WRk4OQ8q4Q=";
  };

  vendorHash = "sha256-VsZcdbOGRbHfjKPU+Y01xZCBq4fiVi7qoRBY9AqS0PM=";
}
