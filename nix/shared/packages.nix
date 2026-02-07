{
  pkgs,
  inputs,
  ...
}: {
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

      claude-code
      codex

      docker

      alejandra # nix formatter
      nil # nix language server

      # To move a package to a specific machine, remove it from here
      # and add it to nix/machines/<machine>/packages.nix instead.
      # Machine-specific packages.nix files use the same
      # `environment.systemPackages` option — nix merges lists automatically.
    ]
    ++ map (pkg: inputs.${pkg}.packages.${pkgs.stdenv.hostPlatform.system}.default)
    [
      "jjui"
      "opencode"
    ];
}
