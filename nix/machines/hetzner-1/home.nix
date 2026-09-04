{
  lib,
  ...
}: {
  nix.gc.options = lib.mkForce "--delete-older-than 3d";

  home.sessionVariables = {
    CARGO_TARGET_DIR = "/home/davidpdrsn/.rust-shared-target";
  };

  programs.ssh.settings = {
    "github.com" = {
      User = "git";
      IdentityFile = "~/.ssh/github";
      IdentitiesOnly = true;
      AddKeysToAgent = "yes";
    };

    "hetzner-2" = {
      IdentityFile = lib.mkForce "~/.ssh/hetzner-to-hetzner-2";
      IdentitiesOnly = lib.mkForce true;
    };
  };

  services.ssh-agent.enable = true;
}
