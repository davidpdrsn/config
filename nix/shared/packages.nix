{
  pkgs,
  inputs,
  ...
}: let
  countTokens = pkgs.callPackage ./packages/count-tokens.nix {};
  piWrapped = import ../lib/pi-wrapped.nix {inherit pkgs inputs;};
in {
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
      piWrapped
    ];
}
