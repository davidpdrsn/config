{
  stdenvNoCC,
  fetchurl,
  lib,
}:

stdenvNoCC.mkDerivation rec {
  pname = "buti";
  version = "2026.09.29.3";

  src = fetchurl {
    url = "https://github.com/BartInTheField/buti/releases/download/${version}/buti_${version}_darwin_arm64.tar.gz";
    hash = "sha256-3yFuxkvnKPgI9buaLc8JXq2Qr2sr9jPatGJ7uoiShOQ=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 buti "$out/bin/buti"
    install -Dm644 LICENSE "$out/share/licenses/buti/LICENSE"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Terminal user interface for GitButler";
    homepage = "https://github.com/BartInTheField/buti";
    license = licenses.mit;
    mainProgram = "buti";
    platforms = ["aarch64-darwin"];
  };
}
