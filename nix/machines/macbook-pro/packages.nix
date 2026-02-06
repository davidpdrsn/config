{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../../shared/packages.nix
  ];

  # Mac-only system packages.
  # Shared packages come from ../../shared/packages.nix.
  # To make a shared package mac-only, move it here from shared/packages.nix.
  environment.systemPackages = with pkgs;
    let
      opWrapped = import ../../lib/op-wrapper.nix {inherit pkgs;};
      test-cli = opWrapped {
        name = "test-cli";
        env = {
          TEST_SECRET = "op://Personal/Test Secret/credential";
        };
        command = /Users/davidpdrsn/.bin/test-cli;
      };
    in [
      # macOS-only packages
      autoraise
      mas
      colima # macOS Docker runtime (docker CLI is in shared)
      nxv
      resvg
      test-cli

      # heavy packages not needed on headless servers
      ffmpeg
      imagemagick
      yt-dlp
      graphviz
    ];

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
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
      "bluesnooze"
      "deckset"
      "discord"
      "ghostty"
      "google-chrome"
      "keyboard-maestro"
      "keymapp"
      "obs"
      "obsidian"
      "raycast"
      "sf-symbols"
      "signal"
      "slack"
      "spotify"
      "steam"
      "superwhisper"
      "unnaturalscrollwheels"
      "vlc"
      "devutils"
      "arc"
    ];

    masApps = {
      "DaisyDisk" = 411643860;
      "Fantastical" = 975937182;
      "Front and Center" = 1493996622;
      "Numbers" = 409203825;
      "Photomator" = 1444636541;
    };

    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };
}
