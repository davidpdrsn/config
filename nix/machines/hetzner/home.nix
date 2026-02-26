{
  lib,
  osConfig,
  ...
}: {
  programs.ssh.matchBlocks = {
    "github.com" = {
      user = "git";
      identityFile = "~/.ssh/github";
      identitiesOnly = true;
      extraOptions.AddKeysToAgent = "yes";
    };
  }
  // lib.optionalAttrs (osConfig.networking.hostName == "nix-4gb-nbg1-1") {
    "hetzner-2" = {
      identityFile = lib.mkForce "~/.ssh/hetzner-to-hetzner-2";
      identitiesOnly = lib.mkForce true;
    };
  }
  // lib.optionalAttrs (osConfig.networking.hostName == "nix-4gb-nbg1-2") {
    "hetzner-1" = {
      identityFile = lib.mkForce "~/.ssh/hetzner-to-hetzner-1";
      identitiesOnly = lib.mkForce true;
    };
  };

  services.ssh-agent.enable = true;
}
