{...}: {
  programs.ssh.matchBlocks."github.com" = {
    user = "git";
    identityFile = "~/.ssh/github";
    identitiesOnly = true;
    extraOptions.AddKeysToAgent = "yes";
  };

  services.ssh-agent.enable = true;
}
