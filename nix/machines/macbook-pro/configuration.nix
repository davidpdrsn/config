{username, ...}: {
  imports = [
    ../../shared/common.nix
    ./packages.nix
  ];

  # Required because I installed Determinate nix, not vanilla
  nix.enable = false;

  system.primaryUser = username;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;

  system.defaults.NSGlobalDomain._HIHideMenuBar = false;

  system.defaults.dock = {
    autohide = true;
    orientation = "bottom";
    tilesize = 48;
    show-recents = false;
    showhidden = true;
    slow-motion-allowed = true;
    persistent-apps = [
      # no apps in the dock plz
    ];
    magnification = false;
    # hot corners
    # bottom left
    wvous-bl-corner = 2; # mission control
    # bottom right
    wvous-br-corner = 3; # application windows
    # top left
    wvous-tl-corner = 1; # disabled
    # top right
    wvous-tr-corner = 4; # desktop
  };

  # fast key repeat
  system.defaults.NSGlobalDomain.KeyRepeat = 2;

  system.defaults.finder = {
    # use column view by default
    FXPreferredViewStyle = "clmv";

    # show all file extensions
    AppleShowAllExtensions = true;

    # open new finder windows in home directory
    NewWindowTarget = "Home";

    # allow quitting finder
    QuitMenuItem = true;

    # show path bar
    ShowPathbar = true;
  };

  # where to save screenshots
  system.defaults.screencapture.location = "~/Desktop/screenshots/";

  # disable the fn key
  system.defaults.hitoolbox.AppleFnUsageType = "Do Nothing";

  # disable guest account
  system.defaults.loginwindow.GuestEnabled = false;

  # don't show screenshot thumbnail before saving to file
  system.defaults.screencapture.show-thumbnail = false;

  # enable tap to click
  system.defaults.trackpad.Clicking = true;

  # use scroll gesture with the Ctrl (^) modifier key to zoom
  # system.defaults.universalaccess.closeViewScrollWheelToggle = true;
  # ^^^ sometimes fails to be applied

  # disable startup chime
  system.startup.chime = false;

  # disable all the tiling window stuff in macos
  system.defaults = {
    WindowManager.EnableStandardClickToShowDesktop = false;
    WindowManager.EnableTiledWindowMargins = false;
    WindowManager.EnableTilingByEdgeDrag = false;
    WindowManager.EnableTilingOptionAccelerator = false;
    WindowManager.EnableTopTilingByEdgeDrag = false;
  };

  # enable window dragging with gesture
  system.defaults.NSGlobalDomain.NSWindowShouldDragOnGesture = true;

  # allow using touch id for sudo (reattach needed for tmux)
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

  # Install 1Password CLI and copy it to /usr/local/bin/op so the
  # desktop app integration (biometric unlock) works
  programs._1password.enable = true;
}
