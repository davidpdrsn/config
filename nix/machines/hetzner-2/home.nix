{
  config,
  lib,
  pkgs,
  ...
}: {
  nix.gc.options = lib.mkForce "--delete-older-than 3d";

  programs.ssh.settings = {
    "github.com" = {
      User = "git";
      IdentityFile = "~/.ssh/github";
      IdentitiesOnly = true;
      AddKeysToAgent = "yes";
    };

    "hetzner-1" = {
      IdentityFile = lib.mkForce "~/.ssh/hetzner-to-hetzner-1";
      IdentitiesOnly = lib.mkForce true;
    };
  };

  home.packages = [(pkgs.callPackage ../../shared/packages/mail-me.nix {})];

  programs.msmtp.enable = true;

  accounts.email.accounts.gmail = {
    primary = true;
    address = "david.pdrsn@gmail.com";
    userName = "david.pdrsn@gmail.com";
    realName = "David Pedersen";
    # Provision this file separately with mode 0600; never put the secret in Nix.
    passwordCommand = "${pkgs.coreutils}/bin/cat ${lib.escapeShellArg "${config.xdg.configHome}/msmtp/gmail-app-password"}";
    smtp = {
      host = "smtp.gmail.com";
      port = 587;
      tls = {
        enable = true;
        useStartTls = true;
      };
    };
    msmtp = {
      enable = true;
      extraConfig.timeout = "15";
    };
  };

  services.ssh-agent.enable = true;
}
