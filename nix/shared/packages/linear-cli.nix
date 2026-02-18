{stdenvNoCC, fetchurl, lib}:

let
  version = "1.10.0";
in
  stdenvNoCC.mkDerivation {
    pname = "linear-cli";
    inherit version;

    src = fetchurl {
      url = "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-aarch64-apple-darwin.tar.xz";
      hash = "sha256-gpxeAIKLgmc+UXTtFFME6pra5MElj7frWbGNSJQk7Ak=";
    };

    dontBuild = true;
    dontConfigure = true;
    dontFixup = true;

    sourceRoot = "linear-aarch64-apple-darwin";

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
      platforms = ["aarch64-darwin"];
    };
  }
