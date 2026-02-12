{self, ...}: {
  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

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
