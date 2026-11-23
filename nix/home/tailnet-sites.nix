# Sites reachable at https://<name>.tailbfde08.ts.net, on every machine. Each
# machine's home.nix sets services.tailnet-sites.machine, and runs the nodes for
# its own sites. Start each site yourself on its port. The directory at
# https://sites.tailbfde08.ts.net links to them all; switch its machine after
# adding a site elsewhere, so the page lists it.
#
# The Mac logs new nodes in with the OAuth client from 1Password. A server reads
# it from ~/.config/tailnet-sites/oauth-client, which
# `just tailnet-sites-secret <host>` writes.
{
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
      stonks = {
        machine = "macbook-pro";
        port = 7418;
      };
      website = {
        machine = "hetzner-1";
        port = 3001;
      };
    };
  };
}
