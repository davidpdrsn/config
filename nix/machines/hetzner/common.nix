{
  lib,
  pkgs,
  inputs,
  username,
  ...
}: {
  imports = [
    ../../shared/common.nix
    ../../shared/packages.nix
  ];

  environment.systemPackages = with pkgs; [
    jjui
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIlDnL40PQbOKkpZXL77p+ub12HFEDMB6BwFToQ2UHMw david.pdrsn@gmail.com"
  ];

  programs.fish.enable = true;
  programs.fish.shellInit = ''
    if not contains /run/wrappers/bin $PATH
      set -gx PATH /run/wrappers/bin $PATH
    end
  '';

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = lib.mkDefault ["wheel"];
    homeMode = "700";
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIlDnL40PQbOKkpZXL77p+ub12HFEDMB6BwFToQ2UHMw david.pdrsn@gmail.com"
    ];
    shell = pkgs.fish;
  };

  environment.extraInit = ''
    export PATH="/run/wrappers/bin:$PATH"
  '';

  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  services.fail2ban.enable = true;

  security.sudo.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = lib.mkDefault [22];
  };

  system.stateVersion = "25.05";
}
