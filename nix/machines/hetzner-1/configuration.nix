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

  environment.systemPackages = [activateDnd];
  security.sudo.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "/run/current-system/sw/bin/activate-dnd-character-sheet";
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
