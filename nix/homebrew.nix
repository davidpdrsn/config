{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    mas
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
      "linear-linear"
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
}
