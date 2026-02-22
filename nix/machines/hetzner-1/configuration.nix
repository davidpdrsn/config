{
  username,
  ...
}: {
  imports = [
    ../hetzner/common.nix
    ./hardware.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "nix-4gb-nbg1-1";

  users.users.${username}.extraGroups = ["wheel" "docker"];

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

  virtualisation.docker.enable = true;
  networking.firewall.allowedTCPPorts = [22 80 443];
}
