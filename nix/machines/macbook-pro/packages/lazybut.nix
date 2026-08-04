{
  stdenvNoCC,
  fetchurl,
  lib,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lazybut";
  version = "0.1.33";

  src = fetchurl {
    url = "https://github.com/OrdalieTech/LazyBut/releases/download/v${version}/lazybut_darwin_arm64.tar.gz";
    hash = "sha256-2vVxm8+Wg4fH5uBqEhQee96EhyvCEXpDGUBa7UAvnnI=";
  };

  sourceRoot = ".";

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 lazybut "$out/bin/lazybut"

    runHook postInstall
  '';

  meta = with lib; {
    description = "LazyGit-inspired terminal client for GitButler";
    homepage = "https://github.com/OrdalieTech/LazyBut";
    license = licenses.mit;
    mainProgram = "lazybut";
    platforms = ["aarch64-darwin"];
  };
}
