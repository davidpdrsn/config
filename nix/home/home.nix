{config, lib, pkgs, ...}: {
  imports = [
    ./sh.nix
    ./ssh.nix
    ./vcs.nix
    ./ripgrep.nix
    ./tmux.nix
    ./codex.nix
    ./pi-agent.nix
    ../lib/pi-agent.nix
  ];

  # Don't change this value, even when updating home-manager.
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv = {
      enable = true;
      # Refresh GC roots without touching the watched .rc cache files, which
      # otherwise cause reloads to bounce between shells in the same project.
      package = pkgs.nix-direnv.overrideAttrs (old: {
        installPhase = old.installPhase + ''
          cd "$out"
          chmod u+w share/nix-direnv/direnvrc
          substituteInPlace share/nix-direnv/direnvrc --replace-fail \
            'if ! touch -h "''${layout_dir}"/flake-profile-* "''${layout_dir}"/flake-inputs/* "''${layout_dir}"/nix-profile-* 2>/dev/null; then' \
            'local root
          for root in "''${layout_dir}"/flake-profile-* "''${layout_dir}"/flake-inputs/* "''${layout_dir}"/nix-profile-*; do
            [[ -L $root ]] || continue
            if ! touch -h "$root" 2>/dev/null; then' \
            --replace-fail '_nix_direnv_warning "could not refresh gcroots; layout directory may be read-only"
            fi' \
            '_nix_direnv_warning "could not refresh gcroots; layout directory may be read-only"
            fi
          done'
        '';
      });
    };
  };

  home.packages = [
    pkgs.neovim
    pkgs.tree-sitter
  ];

  # Work around nixpkgs#485682, which emits a broken string-context warning
  # while generating the Home Manager options documentation.
  manual.manpages.enable = false;

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      enter_accept = false;
    };
  };

  home.file = {
    ".bin".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/bin";
    ".stylua.toml".source = ./../../stylua/stylua.toml;
    ".config/ghostty".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/ghostty";
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/nvim";
    ".config/jjui".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/jjui";
    ".config/opencode".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/opencode";
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/claude/settings.json";
    ".config/vmux".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/vmux";
    ".config/key-weaver".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/key-weaver";
    ".ssh/known_hosts_hetzner".text = ''
      hetzner-1 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDTrvqqopEOL+XGqbsQugUqaKOBx7foziysoB7oIMUnr
      46.225.16.43 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDTrvqqopEOL+XGqbsQugUqaKOBx7foziysoB7oIMUnr
      hetzner-2 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnytj8FmLxKn36zdZjWFbcaJyLrqTBm/C1zEqtbWah6
      46.225.17.37 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnytj8FmLxKn36zdZjWFbcaJyLrqTBm/C1zEqtbWah6
    '';
  } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    ".config/git/allowed_signers".text = ''
      david.pdrsn@gmail.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFvO65GGpQLI6lCjDPo0Owyp222vjG1RAkc0eKmWAWbE
    '';
  };

  home.activation.createFolders = ''
    mkdir -p ~/.config

    mkdir -p .config/cli
    touch .config/cli/history
  '';
}
