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
}
