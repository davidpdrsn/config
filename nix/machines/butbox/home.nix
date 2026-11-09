{...}: {
  home.sessionPath = ["/home/davidpdrsn/.local/bin"];

  programs.ssh.settings = {
    "github.com" = {
      User = "git";
      IdentityFile = "~/.ssh/github";
      IdentitiesOnly = true;
      AddKeysToAgent = "yes";
    };
  };

  services.ssh-agent.enable = true;
}
