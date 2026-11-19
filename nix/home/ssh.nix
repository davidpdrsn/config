{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      };
      "butbox" = {
        HostName = "3.72.241.28";
        User = "davidpdrsn";
        IdentityFile = "~/.ssh/servers";
        IdentitiesOnly = true;
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts_butbox";
      };
      "bi-web bi-worker-1 bi-worker-2" = {
        HostName = "%h.meerkat-delta.ts.net";
        User = "bi";
      };
      "46.225.16.43" = {
        User = "davidpdrsn";
        IdentityFile = "~/.ssh/servers";
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
      };
      "46.225.17.37" = {
        User = "davidpdrsn";
        IdentityFile = "~/.ssh/servers";
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
      };
      "hetzner-1" = {
        HostName = "46.225.16.43";
        User = "davidpdrsn";
        IdentityFile = "~/.ssh/servers";
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
      };
      "hetzner-2" = {
        HostName = "46.225.17.37";
        User = "davidpdrsn";
        IdentityFile = "~/.ssh/servers";
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts_hetzner";
      };
    };
  };
}
