{config, ...}: {
  # Mac-specific SSH: UseKeychain + colima
  programs.ssh.includes = ["${config.home.homeDirectory}/.colima/ssh_config"];
  programs.ssh.matchBlocks."*".extraOptions.UseKeychain = "yes";

  # Mac-specific env vars
  home.sessionVariables = {
    TERMINAL = "ghostty";
    # required for go test containers to work with colima
    DOCKER_HOST = "unix://${config.home.homeDirectory}/.colima/default/docker.sock";
    TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = "/var/run/docker.sock";
  };

  # Mac-specific shell aliases
  programs.fish.shellAliases = {
    o = "open .";
  };

  # Mac-specific activation
  home.activation.createMacFolders = ''
    mkdir -p ~/Desktop/screenshots
    mkdir -p ~/code/dev-tools
  '';

  # might have to run this once
  #   ssh-add --apple-use-keychain ~/.ssh/github_plans_macbook_pro
  home.activation.addGithubKeyToKeychain = ''
    key="${config.home.homeDirectory}/.ssh/github_plans_macbook_pro"
    if [ -f "$key" ]; then
      if [ -z "''${SSH_AUTH_SOCK:-}" ]; then
        export SSH_AUTH_SOCK="$(/bin/launchctl getenv SSH_AUTH_SOCK || true)"
      fi
      /usr/bin/ssh-add --apple-use-keychain "$key" >/dev/null 2>&1 || true
    fi
  '';
}
