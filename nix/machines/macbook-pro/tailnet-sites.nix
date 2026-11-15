# Sites reachable at https://<name>.tailbfde08.ts.net. Start each site yourself
# on its port. The directory at https://sites.tailbfde08.ts.net links to them all.
# `just switch` logs new nodes in with the auth key from 1Password.
{
  imports = [../../lib/tailnet-sites.nix];

  services.tailnet-sites = {
    enable = true;
    tailnet = "tailbfde08.ts.net";
    sites = {
      factory.port = 7417;
    };
  };
}
