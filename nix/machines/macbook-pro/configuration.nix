{
  pkgs,
  username,
  ...
}: {
  imports = [
    ../../shared/common.nix
    ./packages.nix
  ];

  # Required because I installed Determinate nix, not vanilla
  nix.enable = false;

  system.primaryUser = username;

  # nix-darwin only sets the login shell of users in knownUsers, and those need
  # their uid. 501 is the uid macOS gave the first account. For an existing
  # user, activation only sets the primary group (20, staff) and the shell.
  # programs.fish.enable puts the nix paths in fish's PATH. environment.shells
  # adds fish to /etc/shells, which chsh checks.
  programs.fish.enable = true;
  environment.shells = [pkgs.fish];
  users.knownUsers = [username];
  users.users.${username} = {
    uid = 501;
    shell = pkgs.fish;
  };

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
      "/Applications/Ghostty.app"
      "/Applications/Arc.app"
      "/Applications/Discord.app"
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
  # macOS reliable minimums (faster/shorter than defaults)
  system.defaults.NSGlobalDomain.KeyRepeat = 2;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 15;

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
  system.defaults.CustomUserPreferences = {
    "com.apple.AppleMultitouchTrackpad" = {
      Clicking = true;
    };
    "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
      Clicking = true;
    };
    NSGlobalDomain = {
      "com.apple.mouse.tapBehavior" = 1;
    };
  };

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

  programs.ssh.extraConfig = ''
    Host github.com
      User git
      IdentityFile /Users/${username}/.ssh/id_ed25519
      IdentitiesOnly yes
  '';

  # The open-source tailscaled from nixpkgs, run as a launchd daemon. It has no
  # menu bar app; use the tailscale CLI. A new install logs in with
  # `sudo tailscale up`. The tailnet-sites node runs its own tailscaled.
  services.tailscale.enable = true;

  # tailscaled writes its own files to /etc/resolver, including one for the
  # tailnet's domain. It reports a health warning when it finds a symlink out of
  # the directory there, so don't add nix-darwin's resolver file for ts.net.
  environment.etc."resolver/ts.net".enable = false;

  # Without a HostName the Mac takes the one DHCP hands out ("Mac.home"), and
  # tailscaled names the node after it. This matches the LocalHostName.
  networking.hostName = "Davids-MacBook-Pro";

  # Install 1Password CLI and copy it to /usr/local/bin/op so the
  # desktop app integration (biometric unlock) works
  programs._1password.enable = true;
}
