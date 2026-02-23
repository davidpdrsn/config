{
  pkgs,
  inputs,
  username,
  ...
}: let
  mkRuntimeBinLink = pkg: let
    exe = pkgs.lib.getExe pkg;
    binName = builtins.baseNameOf exe;
  in "L+ /home/${username}/config/bin/${binName} - - - - ${exe}";

  gog = pkgs.stdenvNoCC.mkDerivation {
    pname = "gog";
    version = "0.11.0";

    src = pkgs.fetchurl {
      url =
        if pkgs.stdenv.hostPlatform.isAarch64
        then "https://github.com/steipete/gogcli/releases/download/v0.11.0/gogcli_0.11.0_linux_arm64.tar.gz"
        else "https://github.com/steipete/gogcli/releases/download/v0.11.0/gogcli_0.11.0_linux_amd64.tar.gz";
      hash =
        if pkgs.stdenv.hostPlatform.isAarch64
        then "sha256-G/6YBUVkFQFIj+2Txm/HZnHHKkYFKF9XRXLaxwDv3TU="
        else "sha256-ypi6VuKczTcT/nv4Nf3KAK4bl83LewvF45Pn7bQInIQ=";
    };

    dontBuild = true;
    dontConfigure = true;
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -Dm755 gog "$out/bin/gog"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Google CLI for Gmail, Calendar, Drive, and Contacts";
      homepage = "https://github.com/steipete/gogcli";
      license = licenses.mit;
      mainProgram = "gog";
      platforms = platforms.linux;
    };
  };

  goplaces = pkgs.stdenvNoCC.mkDerivation {
    pname = "goplaces";
    version = "0.3.0";

    src = pkgs.fetchurl {
      url =
        if pkgs.stdenv.hostPlatform.isAarch64
        then "https://github.com/steipete/goplaces/releases/download/v0.3.0/goplaces_0.3.0_linux_arm64.tar.gz"
        else "https://github.com/steipete/goplaces/releases/download/v0.3.0/goplaces_0.3.0_linux_amd64.tar.gz";
      hash =
        if pkgs.stdenv.hostPlatform.isAarch64
        then "sha256-IhwA/xN7SqdoNd7WB+RtOKHsmGyo+62IZDBEDWfevRs="
        else "sha256-z6eNTZo2K7wsPT/3d3Fg+1pZlN5+hSGwBIG3LUBTsec=";
    };

    dontBuild = true;
    dontConfigure = true;
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -Dm755 goplaces "$out/bin/goplaces"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Modern Go client + CLI for the Google Places API (New)";
      homepage = "https://github.com/steipete/goplaces";
      license = licenses.mit;
      mainProgram = "goplaces";
      platforms = platforms.linux;
    };
  };

  # inputs.atlas-nixpkgs.legacyPackages.${system}.atlas
  # inputs.oapi-codegen-nixpkgs.legacyPackages.${system}.oapi-codegen
  # inputs.golangci-lint-nixpkgs.legacyPackages.${system}.golangci-lint
  # inputs.gotools-nixpkgs.legacyPackages.${system}.gotools

  linearCli = pkgs.callPackage ../../shared/packages/linear-cli.nix {};
  openclawCli = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openclaw;

  openclawPackages = [
    pkgs.chromium
    pkgs.curl
    pkgs.ffmpeg
    pkgs.gcc
    pkgs.gh
    pkgs.git
    pkgs.gnutar
    pkgs.go
    pkgs.golangci-lint
    pkgs.golines
    pkgs.gopls
    pkgs.gotools
    pkgs.himalaya
    linearCli
    pkgs.nix
    pkgs.nodejs_24
    pkgs.playwright-test
    pkgs.pnpm
    pkgs.uv
    pkgs.wget
    gog
    goplaces
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    openclawCli
  ];
in {
  imports = [
    ../hetzner/common.nix
    ./hardware.nix
  ];

  environment.systemPackages =
    [
      # other packages not available to openclaw
    ]
    ++ openclawPackages;

  systemd.tmpfiles.rules = map mkRuntimeBinLink openclawPackages;

  system.activationScripts.openclawRuntimeBinLinks.text = ''
    ${pkgs.coreutils}/bin/mkdir -p /home/${username}/config/bin
    ${pkgs.systemd}/bin/systemd-tmpfiles --create --prefix=/home/${username}/config/bin
  '';

  systemd.services.openclaw-browser-watchdog = {
    description = "Keep OpenClaw browser automation healthy";
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      Type = "oneshot";
      User = username;
      Group = "users";
      WorkingDirectory = "/home/${username}";
      Environment = ["HOME=/home/${username}"];
    };

    script = ''
      set -euo pipefail

      if ! ${openclawCli}/bin/openclaw browser status --json | ${pkgs.jq}/bin/jq -e '.running and .cdpReady and .cdpHttp' >/dev/null 2>&1; then
        ${openclawCli}/bin/openclaw gateway restart >/dev/null 2>&1 || ${openclawCli}/bin/openclaw gateway start >/dev/null 2>&1 || true
        sleep 2
        ${openclawCli}/bin/openclaw browser start >/dev/null 2>&1 || true
      fi
    '';
  };

  systemd.timers.openclaw-browser-watchdog = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
      Unit = "openclaw-browser-watchdog.service";
    };
  };

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  networking.hostName = "nix-4gb-nbg1-2";

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      stdenv.cc.libc
    ];
  };

  environment.sessionVariables = {
    PNPM_HOME = "/home/${username}/.bin";
  };
}
