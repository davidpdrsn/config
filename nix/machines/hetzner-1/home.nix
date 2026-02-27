{
  lib,
  ...
}: {
  home.sessionVariables = {
    CARGO_TARGET_DIR = "/home/davidpdrsn/.rust-shared-target";
  };

  programs.ssh.matchBlocks = {
    "github.com" = {
      user = "git";
      identityFile = "~/.ssh/github";
      identitiesOnly = true;
      extraOptions.AddKeysToAgent = "yes";
    };

    "hetzner-2" = {
      identityFile = lib.mkForce "~/.ssh/hetzner-to-hetzner-2";
      identitiesOnly = lib.mkForce true;
    };
  };

  services.ssh-agent.enable = true;
}
