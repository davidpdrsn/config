{pkgs, ...}: let
  countTokens = pkgs.callPackage ./packages/count-tokens.nix {};
in {
  # Coding agents (pi, codex, ...) and tools built on them are listed
  # per machine, not here.
  environment.systemPackages = with pkgs;
    [
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
      jjui
      mergiraf
      ruby_3_4
      speedtest-cli
      stylua
      tokei
      tree
      watchexec
      wget
      hyperfine
      python314
      git-filter-repo
      gitleaks
      just
      alejandra # nix formatter
      nil # nix language server
      oxlint
      countTokens
    ];
}
