{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = ["/Users/davidpdrsn/.colima/ssh_config"];
    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
        extraOptions = {
          UseKeychain = "yes";
        };
      };
      "bitbucket.org" = {
        addKeysToAgent = "yes";
        identityFile = "~/.ssh/bitbucket_lun";
      };
      "46.225.16.43" = {
        user = "davidpdrsn";
        identityFile = "~/.ssh/hetzner";
        extraOptions = {
          AddKeysToAgent = "yes";
          UseKeychain = "yes";
        };
      };
      "hetzner-nixos" = {
        hostname = "46.225.16.43";
        user = "davidpdrsn";
        identityFile = "~/.ssh/hetzner";
      };
    };
  };
}
