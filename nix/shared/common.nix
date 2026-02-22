{self, lib, pkgs, ...}: {
  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  nix.settings.extra-substituters = ["https://cache.numtide.com"];
  nix.settings.extra-trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];

  # Determinate Nix includes /etc/nix/nix.custom.conf from /etc/nix/nix.conf.
  # Keep this cache config in a shared module so it applies on all macOS hosts.
  environment.etc = lib.mkIf pkgs.stdenv.isDarwin {
    "nix/nix.custom.conf".text = ''
      extra-substituters = https://cache.numtide.com
      extra-trusted-substituters = https://cache.numtide.com
      extra-trusted-public-keys = niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=
    '';
  };

  # Set Nix build options for performance
  nix.settings.max-jobs = "auto";
  nix.settings.cores = 0;

  nixpkgs.config.allowUnfree = true;

  # Set Git commit hash for system version.
  system.configurationRevision =
    if (self ? rev)
    then self.rev
    else if (self ? dirtyRev)
    then self.dirtyRev
    else null;
}
