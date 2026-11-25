# Sites reachable at https://<name>.tailbfde08.ts.net, on every machine. Each
# site is a Tailscale Service, hosted by the machine it runs on. Each machine's
# home.nix sets services.tailnet-sites.machine. A site with a package runs on
# its machine, which is the only one that builds it. Start a site without one
# yourself. The directory at https://sites.tailbfde08.ts.net links to them all.
# Its machine defines every service in the tailnet, so switch it first after
# adding a site elsewhere.
#
# The Mac hosts its services on a tagged node of its own, which it logs in with
# the OAuth client from 1Password. The servers host theirs on their own nodes,
# which are tagged tag:server.
{
  pkgs,
  inputs,
  ...
}: let
  app = name: inputs.${name}.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  imports = [../lib/tailnet-sites.nix];

  services.tailnet-sites = {
    machines = ["macbook-pro" "hetzner-1" "hetzner-2" "butbox"];
    tailnet = "tailbfde08.ts.net";
    directory.machine = "macbook-pro";
    sites = {
      # Reads stonks.toml, instruments.toml and the Nordnet export from
      # ~/.local/share/tailnet-sites/stonks. Copy them there yourself; they
      # stay out of git.
      stonks = {
        machine = "hetzner-1";
        port = 7418;
        package = app "stonks";
      };
      website = {
        machine = "hetzner-1";
        port = 3001;
      };
    };
  };
}
