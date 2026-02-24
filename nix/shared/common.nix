{self, lib, pkgs, ...}: {
  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  nix.settings.extra-substituters = ["https://cache.numtide.com"];
  nix.settings.extra-trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];

  # Determinate Nix includes /etc/nix/nix.custom.conf from /etc/nix/nix.conf.
  # Keep this cache config in a shared module so it applies on all macOS hosts.
  environment.etc = lib.mkIf pkgs.stdenv.isDarwin {
    "nix/nix.custom.conf" = {
      text = ''
      extra-substituters = https://cache.numtide.com
      extra-trusted-substituters = https://cache.numtide.com
      extra-trusted-public-keys = niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=
    '';
      knownSha256Hashes = [
        # Determinate Nix installer formats that are safe to replace.
        "6787fade1cf934f82db554e78e1fc788705c2c5257fddf9b59bdd963ca6fec63"
        "3bd68ef979a42070a44f8d82c205cfd8e8cca425d91253ec2c10a88179bb34aa"
      ];
    };

    # Allow first activation to replace known stock /etc/zshenv content.
    "zshenv".knownSha256Hashes = [
      "4e8f7cb9b699511f4ba5f9d5f8de1c9f5efb5c607de88faf5f58b8b9cb38edbf"
    ];
  };

  # Set Nix build options for performance
  nix.settings.max-jobs = "auto";
  nix.settings.cores = 0;

  nixpkgs.config.allowUnfree = true;

  # Set Git commit hash for system version.
  system.configurationRevision =
    if (self ? rev)
    then self.rev
    else if (self ? dirtyRev)
    then self.dirtyRev
    else null;
}
