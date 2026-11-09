{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
    ../hetzner/common.nix
    ./disko.nix
  ];

  # t3.medium (Nitro): UEFI boot, NVMe root volume, ENA networking.
  ec2.efi = true;
  nixpkgs.hostPlatform = "x86_64-linux";

  # Don't let EC2 user-data replace this configuration on boot.
  virtualisation.amazon-init.enable = false;

  # amazon-image.nix allows key-only root logins; keep root locked like the other servers.
  services.openssh.settings.PermitRootLogin = lib.mkForce "no";

  networking.hostName = "butbox";
}
