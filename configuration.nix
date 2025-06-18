inputs @ {
  self,
  pkgs,
  ...
}: let
in {
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

  environment.systemPackages = with pkgs; [
    # general
    alejandra
    bat
    cargo-limit
    cargo-outdated
    cargo-watch
    curl
    dust
    eza
    fd
    fzf
    gh
    htop
    hyperfine
    jq
    neovim
    postgresql
    procs
    stylua
    tokei
    tree
    wget

    # rust
    rustup

    # ai
    amp-cli
    claude-code

    # docker
    colima
    docker
    docker-compose

    # gui apps
    code-cursor
    blender
    obsidian
    slack
    spotify
    keymapp
    unnaturalscrollwheels
    google-chrome
  ];

  homebrew = {
    enable = true;
    taps = [
      "homebrew/cask"
    ];
    casks = [
      "discord"
      "ghostty"
      "godot-mono"
      "obs"
      "raycast"
      "signal"
      "steam"
    ];
    masApps = {
      "Front and Center" = 1493996622;
      # "Photomator" = 1444636541;
    };
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;
    dataDir = "/Users/davidpdrsn/.nix-services/postgresql-17";
  };

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;

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
    wvous-br-corner = 1; # disabled
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
  system.defaults.universalaccess.closeViewScrollWheelToggle = true;

  # disable startup chime
  system.startup.chime = false;

  system.defaults.WindowManager.EnableStandardClickToShowDesktop = false;
  system.defaults.WindowManager.EnableTiledWindowMargins = false;
  system.defaults.WindowManager.EnableTilingByEdgeDrag = false;
  system.defaults.WindowManager.EnableTilingOptionAccelerator = false;
  system.defaults.WindowManager.EnableTopTilingByEdgeDrag = false;

  security.pam.services.sudo_local.touchIdAuth = true;
}
