{
  inputs,
  self,
  pkgs,
  ...
}: {
  imports = [
    ./../common.nix
  ];

  # Required because I installed Determinate nix, not vanilla
  nix.enable = false;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  system.primaryUser = "davidpdrsn";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  nixpkgs.config.allowUnfree = true;

  environment.shells = with pkgs; [nushell zsh];

  environment.systemPackages = with pkgs;
    [
      autoraise
      mas
    ]
    ++
    # personal dev tools
    map (pkg: inputs.${pkg}.packages.${pkgs.system}.default)
    [
      "smart-pwd-2"
      "is-vim-running"
      # "git-prompt"
      "git-remove-merged-branches"
      "replace"
      "remove-indentation"
      "git-branch-picker"
      "go-insert-error"
    ];

  homebrew = {
    enable = true;
    taps = [
      "homebrew/cask"
    ];
    brews = [
      # install things with nixpkgs if at all possible!
    ];
    casks = [
      "1password"
      "blender"
      "discord"
      "ghostty"
      "godot-mono"
      "google-chrome"
      "keyboard-maestro"
      "keymapp"
      "obs"
      "obsidian"
      "raycast"
      "signal"
      "slack"
      "spotify"
      "steam"
      "unnaturalscrollwheels"
      "vlc"
    ];
    masApps = {
      "Fantastical" = 975937182;
      "Front and Center" = 1493996622;
      "Photomator" = 1444636541;
    };
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };

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
    autohide-delay = 0.0;
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

  # allow using touch id for sudo
  security.pam.services.sudo_local.touchIdAuth = true;
}
