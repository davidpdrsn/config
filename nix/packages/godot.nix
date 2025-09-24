{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "godot";
  version = "4.4.1-stable";

  src = pkgs.fetchurl {
    url = "https://github.com/godotengine/godot/releases/download/${version}/Godot_v${version}_mono_macos.universal.zip";
    sha256 = "sha256-MlvoIyhM5JFIemmzVNu0gYdYV77oSgsdAMJVLOqSwKc=";
  };

  nativeBuildInputs = [ pkgs.unzip ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/Applications
    cp -r Godot_mono.app $out/Applications/
    mkdir -p $out/bin
    ln -s $out/Applications/Godot_mono.app/Contents/MacOS/Godot $out/bin/godot
  '';

  meta = with pkgs.lib; {
    description = "Multi-platform 2D and 3D game engine";
    homepage = "https://godotengine.org";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}