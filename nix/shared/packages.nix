{pkgs, ...}: {
  # Coding agents (pi, codex, ...) and tools built on them are listed
  # per machine, not here.
  environment.systemPackages = with pkgs;
    [
      bat
      curl
      eza
      fd
      fzf
      gh
      htop
      jq
      jjui
      ruby_3_4
      stylua
      tokei
      tree
      watchexec
      hyperfine
      python314
      just
      alejandra # nix formatter
      nil # nix language server
      oxlint
    ];
}
