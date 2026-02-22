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
      "46.225.17.37" = {
        user = "davidpdrsn";
        identityFile = "~/.ssh/hetzner";
      };
      "hetzner-1" = {
        hostname = "46.225.16.43";
        user = "davidpdrsn";
        identityFile = "~/.ssh/hetzner";
      };
      "hetzner-2" = {
        hostname = "46.225.17.37";
        user = "davidpdrsn";
        identityFile = "~/.ssh/hetzner";
      };
    };
  };
}
