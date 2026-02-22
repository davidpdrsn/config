{
  pkgs,
  username,
  ...
}: {
  imports = [
    ../../shared/common.nix
    ../../shared/packages.nix
    ./hardware.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "nix-4gb-nbg1-1";

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIlDnL40PQbOKkpZXL77p+ub12HFEDMB6BwFToQ2UHMw david.pdrsn@gmail.com"
  ];

  programs.fish.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "docker"];
    homeMode = "700";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIlDnL40PQbOKkpZXL77p+ub12HFEDMB6BwFToQ2UHMw david.pdrsn@gmail.com"
    ];
    shell = pkgs.fish;
  };

  # Ensure setuid wrappers (like sudo) are found before nix store binaries
  environment.extraInit = ''
    export PATH="/run/wrappers/bin:$PATH"
  '';

  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      "dnd.davidpdrsn.com" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/var/lib/nginx-secrets/htpasswd";
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:3000";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };
      "davidpdrsn.com" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:3001";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "david.pdrsn@gmail.com";
  };

  # htpasswd managed manually on the server:
  #   nix-shell -p apacheHttpd --run "sudo htpasswd -Bc /var/lib/nginx-secrets/htpasswd ollie"
  #   sudo chown root:nginx /var/lib/nginx-secrets/htpasswd
  #   sudo chmod 0440 /var/lib/nginx-secrets/htpasswd

  services.fail2ban.enable = true;

  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.dnd-character-sheet = {
      image = "dnd-character-sheet:latest";
      autoStart = true;
      ports = ["127.0.0.1:3000:3000"];
      volumes = ["/home/${username}/dnd/data:/data/characters"];
    };
    containers.website = {
      image = "website:latest";
      autoStart = true;
      ports = ["127.0.0.1:3001:3000"];
    };
  };

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
    allowedTCPPorts = [22 80 443];
  };

  # NEVER change this
  system.stateVersion = "25.05";
}
