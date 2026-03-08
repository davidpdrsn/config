{
  username,
  inputs,
  ...
}: {
  imports = [
    ../hetzner/common.nix
    ./hardware.nix
    inputs.fyc-site.nixosModules.default
    inputs.website.nixosModules.default
    inputs."dnd-character-sheet".nixosModules.default
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "nix-4gb-nbg1-1";

  services.fyc-site = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 3002;
    # Must contain at least: FYC_SITE_COOKIE_SECRET=...
    environmentFile = "/run/secrets/fyc-site.env";
    secureCookies = true;
  };

  services.website = {
    enable = true;
    port = 3001;
  };

  services."dnd-character-sheet" = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 3000;
    charactersDir = "/var/lib/dnd-character-sheet";
    dynamicUser = false;
    # Share access with davidpdrsn via the users group.
    group = "users";
  };

  users.users.${username} = {
    extraGroups = ["wheel" "docker"];
  };

  systemd.services.dnd-character-sheet.serviceConfig = {
    StateDirectory = "dnd-character-sheet";
    StateDirectoryMode = "0770";
    User = "dnd-character-sheet";
    Group = "users";
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
      "fyc.davidpdrsn.com" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:3002";
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

  virtualisation.docker.enable = true;
  networking.firewall.allowedTCPPorts = [22 80 443];
}
