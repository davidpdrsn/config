{
  pkgs,
  inputs,
  username,
  ...
}: let
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

  linearCli = pkgs.callPackage ../../shared/packages/linear-cli.nix {};
  cloudAgent = pkgs.callPackage ../../shared/packages/cloud-agent.nix {};
  obsidianVaultsPull = import ../../lib/obsidian-vaults-pull.nix {
    inherit pkgs username;
  };
  piWrapped = import ../../lib/pi-wrapped.nix {inherit pkgs inputs;};

  serverPackages = [
    cloudAgent
    gog
    goplaces
    linearCli
    piWrapped
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
  ];
in {
  imports = [
    ../hetzner/common.nix
    ./hardware.nix
  ];

  environment.systemPackages = serverPackages;

  systemd.tmpfiles.rules = [
    "d /srv/gitbutler-nfs 0755 ${username} users - -"
  ];

  systemd.services.obsidian-vaults-pull = obsidianVaultsPull.service;
  systemd.timers.obsidian-vaults-pull = obsidianVaultsPull.timer;

  systemd.services.gitbutler-pr-digest = {
    description = "Email the daily GitButler merged PR digest";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    path = [(pkgs.callPackage ../../shared/packages/mail-me.nix {})];
    environment.HOME = "/home/${username}";
    serviceConfig = {
      Type = "oneshot";
      User = username;
      WorkingDirectory = "/home/${username}";
      TimeoutStartSec = "2h";
    };
    script = ''
      set -euo pipefail
      /run/current-system/sw/bin/pr-digest gitbutlerapp/gitbutler |
        mail-me --html "GitButler daily PR digest"
    '';
  };

  systemd.timers.gitbutler-pr-digest = {
    description = "Send the GitButler PR digest at 16:00 Copenhagen time";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 16:00:00 Europe/Copenhagen";
      Persistent = true;
      AccuracySec = "1s";
    };
  };

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  networking.hostName = "nix-4gb-nbg1-2";

  users.users.${username}.extraGroups = ["wheel" "docker"];

  virtualisation.docker.enable = true;

  services.nfs.server = {
    enable = true;
    hostName = "127.0.0.1";
    exports = ''
      /srv/gitbutler-nfs 127.0.0.1(rw,sync,no_subtree_check,insecure,fsid=0,all_squash,anonuid=1000,anongid=100)
    '';
  };

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
