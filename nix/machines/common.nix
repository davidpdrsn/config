{pkgs, inputs, ...}: {
  environment.systemPackages = with pkgs; [
    # general
    bat
    cargo-limit
    cargo-outdated
    cargo-watch
    curl
    eza
    fd
    fzf
    gh
    htop
    jq
    stylua
    tokei
    tree
    wget
    ruby_3_4
    jjui
    ripgrep-all
    mergiraf
    ffmpeg
    watchexec

    alejandra # nix formatter
    nil # nix language server

    # ai
    claude-code
    codex
    opencode

    # docker
    colima
    docker

    # personal dev tools
    inputs.git-history-csv.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.nxv.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
  ];
}
