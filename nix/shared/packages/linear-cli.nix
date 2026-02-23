{
  stdenv,
  stdenvNoCC,
  fetchurl,
  lib,
}:

let
  version = "1.10.0";
  target =
    if stdenv.hostPlatform.isAarch64 && stdenv.hostPlatform.isDarwin
    then "aarch64-apple-darwin"
    else if stdenv.hostPlatform.isx86_64 && stdenv.hostPlatform.isDarwin
    then "x86_64-apple-darwin"
    else if stdenv.hostPlatform.isAarch64 && stdenv.hostPlatform.isLinux
    then "aarch64-unknown-linux-gnu"
    else if stdenv.hostPlatform.isx86_64 && stdenv.hostPlatform.isLinux
    then "x86_64-unknown-linux-gnu"
    else throw "linear-cli: unsupported platform ${stdenv.hostPlatform.system}";

  hash =
    if target == "aarch64-apple-darwin"
    then "sha256-gpxeAIKLgmc+UXTtFFME6pra5MElj7frWbGNSJQk7Ak="
    else if target == "x86_64-apple-darwin"
    then "sha256-5HccJyxSjrCJbvEABBImfbgFDbLRiyP4HOFMylbR+DA="
    else if target == "aarch64-unknown-linux-gnu"
    then "sha256-QhBfvG5T67x3zpVVkcTPx+WL2+5niMYXbmoq/Hx2fko="
    else "sha256-UZUYUkcHmh/cCM2xAxAeJrG1sdBj1fTB2n7HknjTdVg=";

in
  stdenvNoCC.mkDerivation {
    pname = "linear-cli";
    inherit version;

    src = fetchurl {
      url = "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-${target}.tar.xz";
      inherit hash;
    };

    dontBuild = true;
    dontConfigure = true;
    dontFixup = true;

    sourceRoot = "linear-${target}";

    installPhase = ''
      runHook preInstall
      install -Dm755 linear "$out/bin/linear"

      runHook postInstall
    '';

    meta = with lib; {
      description = "CLI for Linear issue tracker";
      homepage = "https://github.com/schpet/linear-cli";
      license = licenses.mit;
      mainProgram = "linear";
      platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
    };
  }
