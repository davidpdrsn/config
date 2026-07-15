{
  inputs,
  lib,
  pkgs,
  ...
}: let
  openclawCli = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openclaw;
in {
  nix.gc.options = lib.mkForce "--delete-older-than 3d";

  programs.ssh.matchBlocks = {
    "github.com" = {
      user = "git";
      identityFile = "~/.ssh/github";
      identitiesOnly = true;
      extraOptions.AddKeysToAgent = "yes";
    };

    "hetzner-1" = {
      identityFile = lib.mkForce "~/.ssh/hetzner-to-hetzner-1";
      identitiesOnly = lib.mkForce true;
    };
  };

  services.ssh-agent.enable = true;

  home.activation.openclawConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${openclawCli}/bin/openclaw config set skills.load.extraDirs '["/home/davidpdrsn/config/openclaw/skills"]' --json >/dev/null
    ${openclawCli}/bin/openclaw config set agents.defaults.model.primary openai/gpt-5.4 >/dev/null
  '';

  home.activation.openclawGateway = lib.hm.dag.entryAfter ["openclawConfig"] ''
    unit="$HOME/.config/systemd/user/openclaw-gateway.service"

    if ! ${pkgs.gnugrep}/bin/grep -Fq '${openclawCli}/lib/openclaw/' "$unit" 2>/dev/null; then
      ${openclawCli}/bin/openclaw gateway install --force >/dev/null
      ${pkgs.systemd}/bin/systemctl --user restart openclaw-gateway.service
    fi
  '';
}
