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
  obsidianVaultRepo = "/home/${username}/obsidian-vaults";
  obsidianPullStateDir = "/home/${username}/.local/state/obsidian-vaults-pull";

  obsidianVaultsPullScript = pkgs.writeShellScript "obsidian-vaults-pull" ''
    set -euo pipefail

    repo='${obsidianVaultRepo}'
    state_dir='${obsidianPullStateDir}'
    state_file="$state_dir/last-status"

    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

    old_status=""
    if [ -f "$state_file" ]; then
      old_status="$(<"$state_file")"
    fi

    new_status="ok"
    message=""

    notify() {
      local text="$1"
      ${pkgs.lib.getExe openclawCli} message send \
        --channel telegram \
        --target 8355979215 \
        --message "$text" >/dev/null 2>&1 || true
    }

    fail() {
      local status="$1"
      local text="$2"
      new_status="$status"
      message="$text"
    }

    if [ ! -d "$repo" ]; then
      fail "path_missing" "Obsidian pull failed: $repo does not exist"
    fi

    if [ "$new_status" = "ok" ] && ! ${pkgs.lib.getExe pkgs.git} -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      fail "not_git_repo" "Obsidian pull failed: $repo is not a git repository"
    fi

    branch=""
    if [ "$new_status" = "ok" ]; then
      branch="$(${pkgs.lib.getExe pkgs.git} -C "$repo" symbolic-ref --quiet --short HEAD || true)"
    fi
    if [ "$new_status" = "ok" ] && [ -z "$branch" ]; then
      fail "detached_head" "Obsidian pull failed: repository is in detached HEAD"
    fi

    if [ "$new_status" = "ok" ] && [ -n "$(${pkgs.lib.getExe pkgs.git} -C "$repo" status --porcelain)" ]; then
      fail "dirty_worktree" "Obsidian pull skipped: local changes detected in $repo"
    fi

    upstream=""
    if [ "$new_status" = "ok" ] && ! upstream="$(${pkgs.lib.getExe pkgs.git} -C "$repo" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null)"; then
      fail "missing_upstream" "Obsidian pull failed: branch '$branch' has no upstream"
    fi

    pull_output=""
    if [ "$new_status" = "ok" ] && ! pull_output="$(${pkgs.lib.getExe pkgs.git} -C "$repo" pull --ff-only 2>&1)"; then
      fail "pull_failed" "Obsidian pull failed on $branch ($upstream): $pull_output"
    fi

    if [ "$new_status" = "ok" ] && [ "$old_status" != "ok" ] && [ -n "$old_status" ]; then
      notify "Obsidian pull recovered on $branch ($upstream)."
    fi

    if [ "$new_status" != "ok" ] && [ "$new_status" != "$old_status" ]; then
      notify "$message"
    fi

    if [ "$new_status" != "$old_status" ]; then
      printf '%s\n' "$new_status" >"$state_file"
    fi

    if [ "$new_status" != "ok" ]; then
      echo "$message" >&2
      exit 1
    fi

    echo "Obsidian pull succeeded: $pull_output"
  '';

  openclawPackages = [
    gog
    goplaces
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    linearCli
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

  systemd.services.obsidian-vaults-pull = {
    description = "Pull Obsidian vault repository";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      ExecStart = obsidianVaultsPullScript;
    };
  };

  systemd.timers.obsidian-vaults-pull = {
    description = "Run Obsidian vault pull every 30 minutes";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*:0/30";
      Persistent = true;
      Unit = "obsidian-vaults-pull.service";
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
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };
}
