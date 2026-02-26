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
  cloudTmuxStatus = pkgs.callPackage ../../shared/packages/cloud-tmux-status.nix {};
  openclawCli = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openclaw;
  obsidianVaultsPull = import ../../lib/obsidian-vaults-pull.nix {
    inherit pkgs openclawCli username;
  };

  openclawPackages = [
    gog
    goplaces
    linearCli
    cloudTmuxStatus
    openclawCli
    pkgs.chromium
    pkgs.curl
    pkgs.fd
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
    pkgs.graphviz
    pkgs.himalaya
    pkgs.hyperfine
    pkgs.imagemagick
    pkgs.jq
    pkgs.just
    pkgs.khal
    pkgs.nix
    pkgs.nodejs_24
    pkgs.playwright-driver.browsers
    pkgs.playwright-test
    pkgs.pnpm
    pkgs.python314
    pkgs.uv
    pkgs.vdirsyncer
    pkgs.watchexec
    pkgs.wget
    pkgs.wget
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

  systemd.services.obsidian-vaults-pull = obsidianVaultsPull.service;
  systemd.timers.obsidian-vaults-pull = obsidianVaultsPull.timer;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  networking.hostName = "nix-4gb-nbg1-2";

  users.users.${username}.extraGroups = ["wheel" "docker"];

  virtualisation.docker.enable = true;

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      stdenv.cc.libc
    ];
  };

  environment.sessionVariables = {
    PNPM_HOME = "/home/${username}/.bin";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };
}
