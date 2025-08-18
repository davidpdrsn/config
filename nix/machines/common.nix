{pkgs, ...}: {
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

    alejandra # nix formatter
    nil # nix language server

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
