# Sites reachable at https://<name>.tailbfde08.ts.net, on every machine. Each
# machine's home.nix sets services.tailnet-sites.machine, and runs the nodes for
# its own sites. A site with a package runs on its machine, which is the only
# one that builds it. Start a site without one yourself. The directory at
# https://sites.tailbfde08.ts.net links to them all; switch its machine after
# adding a site elsewhere, so the page lists it.
#
# The Mac logs new nodes in with the OAuth client from 1Password. A server reads
# it from ~/.config/tailnet-sites/oauth-client, which
# `just tailnet-sites-secret <host>` writes.
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
      factory = {
        machine = "macbook-pro";
        port = 7417;
      };
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
