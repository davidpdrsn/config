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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBIvdYAU5pJGqdHhXQZ6SWVmQnhHiAVDoJH328Ad3opZ hetzner-1-to-hetzner-2"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKtbQr3RmJBhl2hLONHS1T5ds3TPMqxxMfs9sPDQGcze hetzner-2-to-hetzner-1"
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

  # System-wide SSH config for root/system services (e.g. nix-daemon fetching private flakes).
  programs.ssh = {
    knownHosts = {
      github-ed25519 = {
        hostNames = ["github.com"];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
      github-rsa = {
        hostNames = ["github.com"];
        publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
      };
      github-ecdsa = {
        hostNames = ["github.com"];
        publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
      };
    };

    extraConfig = ''
      Host github.com
        User git
        IdentitiesOnly yes
        IdentityFile /home/${username}/.ssh/github-deploy
        StrictHostKeyChecking yes
    '';
  };

  services.fail2ban.enable = true;

  # Keep only one week of persistent systemd journal logs.
  services.journald.extraConfig = ''
    MaxRetentionSec=7day
  '';

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

  zramSwap.enable = true;

  nix.settings = {
    max-jobs = lib.mkForce 1;
    cores = lib.mkForce 1;
  };

  system.stateVersion = "25.05";
}
