{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      };
      "bitbucket.org" = {
        AddKeysToAgent = "yes";
        IdentityFile = "~/.ssh/bitbucket_lun";
      };
      "46.225.16.43" = {
        User = "davidpdrsn";
        IdentityFile = "~/.ssh/hetzner";
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
      };
      "46.225.17.37" = {
        User = "davidpdrsn";
        IdentityFile = "~/.ssh/hetzner";
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
      };
      "hetzner-1" = {
        HostName = "46.225.16.43";
        User = "davidpdrsn";
        IdentityFile = "~/.ssh/hetzner";
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
      };
      "hetzner-2" = {
        HostName = "46.225.17.37";
        User = "davidpdrsn";
        IdentityFile = "~/.ssh/hetzner";
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
      };
    };
  };
}
