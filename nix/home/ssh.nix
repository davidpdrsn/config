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
        extraOptions = {
          StrictHostKeyChecking = "yes";
          UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
        };
      };
      "46.225.17.37" = {
        user = "davidpdrsn";
        identityFile = "~/.ssh/hetzner";
        extraOptions = {
          StrictHostKeyChecking = "yes";
          UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
        };
      };
      "hetzner-1" = {
        hostname = "46.225.16.43";
        user = "davidpdrsn";
        identityFile = "~/.ssh/hetzner";
        extraOptions = {
          StrictHostKeyChecking = "yes";
          UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
        };
      };
      "hetzner-2" = {
        hostname = "46.225.17.37";
        user = "davidpdrsn";
        identityFile = "~/.ssh/hetzner";
        extraOptions = {
          StrictHostKeyChecking = "yes";
          UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
        };
      };
    };
  };
}
