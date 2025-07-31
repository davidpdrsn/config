{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # general
    alejandra
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
    postgresql
    lldb_20
    yt-dlp
    xh
    ruby
    nil
    watchexec
    btop
    jjui
    ollama
    graphviz
    ripgrep-all

    # ai
    claude-code

    # docker
    colima
    docker
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
  ];
}
