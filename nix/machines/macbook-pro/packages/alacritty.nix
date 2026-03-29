{
  stdenvNoCC,
  fetchurl,
  undmg,
  lib,
}:

stdenvNoCC.mkDerivation rec {
  pname = "alacritty";
  version = "0.16.1";

  src = fetchurl {
    url = "https://github.com/alacritty/alacritty/releases/download/v${version}/Alacritty-v${version}.dmg";
    hash = "sha256-KFUsk5i3MrI67kggaBXSnzcHAoxsqagv2LTA0FyqlAo=";
  };

  nativeBuildInputs = [undmg];

  sourceRoot = ".";

  unpackPhase = ''
    runHook preUnpack
    undmg "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -R "Alacritty.app" "$out/Applications/"
    ln -s "$out/Applications/Alacritty.app/Contents/MacOS/alacritty" "$out/bin/alacritty"

    runHook postInstall
  '';

  meta = with lib; {
    description = "GPU-accelerated terminal emulator";
    homepage = "https://github.com/alacritty/alacritty";
    license = licenses.asl20;
    mainProgram = "alacritty";
    platforms = platforms.darwin;
  };
}
