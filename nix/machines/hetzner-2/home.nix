{lib, ...}: {
  nix.gc.options = lib.mkForce "--delete-older-than 3d";

  programs.ssh.settings = {
    "github.com" = {
      User = "git";
      IdentityFile = "~/.ssh/github";
      IdentitiesOnly = true;
      AddKeysToAgent = "yes";
    };

    "hetzner-1" = {
      IdentityFile = lib.mkForce "~/.ssh/hetzner-to-hetzner-1";
      IdentitiesOnly = lib.mkForce true;
    };
  };

  services.ssh-agent.enable = true;
}
