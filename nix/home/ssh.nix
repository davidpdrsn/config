{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
      };
      "bitbucket.org" = {
        addKeysToAgent = "yes";
        identityFile = "~/.ssh/bitbucket_lun";
      };
      "46.225.16.43" = {
        user = "davidpdrsn";
        identityFile = "~/.ssh/hetzner";
      };
      "hetzner-nixos" = {
        hostname = "46.225.16.43";
        user = "davidpdrsn";
        identityFile = "~/.ssh/hetzner";
      };
    };
  };
}
