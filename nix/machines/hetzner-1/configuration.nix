{
  pkgs,
  lib,
  username,
  inputs,
  ...
}: let
  activateDnd = pkgs.writeShellApplication {
    name = "activate-dnd-character-sheet";
    runtimeInputs = [pkgs.nix pkgs.coreutils pkgs.gnugrep pkgs.util-linux pkgs.systemd];
    text = builtins.readFile ../../../scripts/activate-dnd-character-sheet;
  };
  activateDndNext = pkgs.writeShellApplication {
    name = "activate-dnd-next";
    runtimeInputs = [pkgs.coreutils pkgs.file pkgs.util-linux pkgs.systemd pkgs.curl];
    text = builtins.readFile ../../../scripts/activate-dnd-next;
  };
  obsidianVaultsPull = import ../../lib/obsidian-vaults-pull.nix {
    inherit pkgs username;
  };
in {
  imports = [
    ../hetzner/common.nix
    ./hardware.nix
    inputs.website.nixosModules.default
    inputs."dnd-character-sheet".nixosModules.default
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "nix-4gb-nbg1-1";

  systemd.services.obsidian-vaults-pull = obsidianVaultsPull.service;
  systemd.timers.obsidian-vaults-pull = obsidianVaultsPull.timer;

  services.website = {
    enable = true;
    package = inputs.website.packages.${pkgs.stdenv.hostPlatform.system}.default;
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

  systemd.services.npc-browser = {
    description = "NPC browser";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      ExecStart = "${inputs."npc-browser".packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/npc-browser --notes-dir /home/${username}/obsidian-vaults/dnd --host 127.0.0.1 --port 3003";
      User = username;
      Group = "users";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = "read-only";
      ProtectSystem = "strict";
    };
  };

  users.users.${username} = {
    extraGroups = ["wheel" "docker"];
  };

  users.groups.dnd-next = {};
  users.users.dnd-next = {
    isSystemUser = true;
    group = "dnd-next";
  };
  systemd.tmpfiles.rules = ["d /opt/dnd-next 0755 root root -"];
  systemd.services.dnd-next = {
    description = "D&D character sheet";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    unitConfig.ConditionPathExists = "/opt/dnd-next/dnd-server";
    serviceConfig = {
      ExecStart = "/opt/dnd-next/dnd-server --host 127.0.0.1 --port 3002 --database /var/lib/dnd-next/characters.sqlite";
      User = "dnd-next";
      Group = "dnd-next";
      StateDirectory = "dnd-next";
      StateDirectoryMode = "0700";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 30;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
    };
  };

  environment.systemPackages = [activateDnd activateDndNext];
  security.sudo.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "/run/current-system/sw/bin/activate-dnd-character-sheet";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/activate-dnd-next";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  systemd.services.dnd-character-sheet = {
    # The first deployment creates this profile. Until then, skip startup.
    unitConfig.ConditionPathExists = "/nix/var/nix/profiles/dnd-character-sheet/bin/website";
    serviceConfig = {
      # Keep the app out of the system closure; deploy it with scripts/deploy-dnd.
      ExecStart = lib.mkForce "/nix/var/nix/profiles/dnd-character-sheet/bin/website";
      StateDirectory = "dnd-character-sheet";
      StateDirectoryMode = "0770";
      User = "dnd-character-sheet";
      Group = "users";
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      "dnd-next.davidpdrsn.com" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/var/lib/nginx-secrets/htpasswd";
        locations."~ \\.(css|js)$" = {
          proxyPass = "http://127.0.0.1:3002";
          extraConfig = ''
            # These assets are public, including requests from signed-in browsers.
            auth_basic off;
            proxy_set_header Authorization "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            # Filenames are not fingerprinted, so keep the cache lifetime short.
            add_header Cache-Control "public, max-age=300, s-maxage=300";
          '';
        };
        locations."= /characters/import" = {
          proxyPass = "http://127.0.0.1:3002";
          extraConfig = ''
            # Allow the app's 32 MiB ZIP limit plus multipart form overhead.
            client_max_body_size 33m;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
        locations."/" = {
          proxyPass = "http://127.0.0.1:3002";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
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
      "npc.davidpdrsn.com" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/var/lib/nginx-secrets/htpasswd";
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:3003";
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
