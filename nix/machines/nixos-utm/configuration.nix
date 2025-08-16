{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./../common.nix
  ];

  environment.systemPackages = with pkgs; [
    neovim
    git
    zsh
    xclip
    copyq
  ];

  # For now, we need this since hardware acceleration does not work.
  environment.variables.LIBGL_ALWAYS_SOFTWARE = "1";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable autologin for the graphical session
  services.displayManager.autoLogin = {
    enable = true;
    user = "davidpdrsn";
  };

  # Enable the i3 window manager.
  services.xserver.windowManager.i3 = {
    enable = true;
    configFile = pkgs.writeText "i3-config" ''
      # Set modifier key to Super (Windows key)
      set $mod Mod4

      # Set the font (using the one from your error message)
      font pango:Iosevka_Nerd_Font 10

      # Automatically open a terminal on login
      exec ${pkgs.ghostty}/bin/ghostty

      # Autostart the clipboard manager
      exec --no-startup-id copyq

      # --- Keybindings ---
      # Start a terminal
      bindsym $mod+Return exec ${pkgs.ghostty}/bin/ghostty

      # Kill focused window
      bindsym $mod+Shift+q kill

      # Add any other i3 config lines here, just as you would
      # in a normal ~/.config/i3/config file.
    '';
  };

  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  services.getty.autologinUser = "davidpdrsn";

  boot.initrd.availableKernelModules = ["9p" "9pnet" "9pnet_virtio" "virtio_gpu"];
  boot.kernelModules = ["9pnet_virtio"];

  services.xserver.videoDrivers = ["virtio"];
  hardware.graphics.enable = true;

  # Mount directory shared with host
  fileSystems."/home/davidpdrsn/code" = {
    device = "share";
    fsType = "9p";
    options = [
      "trans=virtio"
      "version=9p2000.L"
      "_netdev"
      "noatime"
      "uid=1000"
      "gid=100"
      "access=user"
    ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";

  networking.networkmanager.enable = true;

  nix.settings.experimental-features = ["nix-command" "flakes"];

  time.timeZone = "Europe/Copenhagen";

  i18n.defaultLocale = "en_DK.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "da_DK.UTF-8";
    LC_IDENTIFICATION = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_NAME = "da_DK.UTF-8";
    LC_NUMERIC = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
    LC_TELEPHONE = "da_DK.UTF-8";
    LC_TIME = "da_DK.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  users.users.davidpdrsn = {
    isNormalUser = true;
    description = "David Pedersen";
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.nushell;
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.05";
}
