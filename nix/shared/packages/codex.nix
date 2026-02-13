{ stdenvNoCC, fetchurl, lib }:

let
  version = "0.101.0";
  release = "rust-v${version}";
  platform = {
    "x86_64-darwin" = {
      target = "x86_64-apple-darwin";
      hash = "sha256-UdTjUXx18JMxMr4zZfM7CANtQ9PCBpKzD1zDbdPqw+k=";
    };
    "aarch64-darwin" = {
      target = "aarch64-apple-darwin";
      hash = "sha256-/Ah+kAK+DhcL/qonZZ43eCHhWrl4tKSQde+V21+CB/g=";
    };
    "x86_64-linux" = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-/zY/hZfb8Dg8F2WefJJzW6qZG+irmflnxcw8aLMpJ3w=";
    };
    "aarch64-linux" = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-9cSxFHMyocxBCLd2x1nue0CdNl5YMKTllmfh+cfm2mA=";
    };
  }.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported platform for OpenAI Codex CLI: ${stdenvNoCC.hostPlatform.system}");

in stdenvNoCC.mkDerivation {
  pname = "openai-codex";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/${release}/codex-${platform.target}.tar.gz";
    hash = platform.hash;
  };

  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    tar -xzf "$src" -C "$TMPDIR"
    install -Dm755 "$TMPDIR/codex-${platform.target}" "$out/bin/codex"
    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
