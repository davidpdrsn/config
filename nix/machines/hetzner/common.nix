{username, ...}: {
  imports = [
    ../../shared/server.nix
  ];

  # Lets hetzner-1 and hetzner-2 SSH into each other.
  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBIvdYAU5pJGqdHhXQZ6SWVmQnhHiAVDoJH328Ad3opZ hetzner-1-to-hetzner-2"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKtbQr3RmJBhl2hLONHS1T5ds3TPMqxxMfs9sPDQGcze hetzner-2-to-hetzner-1"
  ];
}
