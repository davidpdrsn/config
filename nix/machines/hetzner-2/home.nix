{
  lib,
  ...
}: {
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

  home.activation.openclawSkillDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    /run/current-system/sw/bin/openclaw config set skills.load.extraDirs '["/home/davidpdrsn/config/openclaw/skills"]' --json >/dev/null
  '';
}
