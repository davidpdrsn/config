{...}: {
  # Server-specific SSH
  programs.ssh.matchBlocks."github.com" = {
    user = "git";
    identityFile = "~/.ssh/github";
    identitiesOnly = true;
    extraOptions.AddKeysToAgent = "yes";
  };

  # ssh-agent as a systemd user service (Linux-only)
  services.ssh-agent.enable = true;
}
