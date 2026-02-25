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
  environment.systemPackages = with pkgs; let
    opWrapped = import ../../lib/op-wrapper.nix {inherit pkgs;};
    linearCli = pkgs.callPackage ../../shared/packages/linear-cli.nix {};
    test-cli = opWrapped {
      name = "test-cli";
      env = {
        TEST_SECRET = "op://Personal/Test Secret/credential";
      };
      command = /Users/davidpdrsn/.bin/test-cli;
    };
  in
    [
      autoraise
      mas
      colima
      nxv
      resvg
      linearCli
      test-cli
      gettext
      ffmpeg
      imagemagick
      yt-dlp
      graphviz
      google-cloud-sdk
    ]
    ++ (with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      opencode
      codex
      pi
    ])
    ++ map (pkg: inputs.${pkg}.packages.${pkgs.stdenv.hostPlatform.system}.default) [
      "jjui"
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
      "voiceink"
      "unnaturalscrollwheels"
      "vlc"
      "arc"
      "poedit"
      "chatgpt"
      "audio-hijack"
      "blackhole-2ch"
    ];

    masApps = {
      "DaisyDisk" = 411643860;
      "Fantastical" = 975937182;
      "Numbers" = 409203825;
      "Photomator" = 1444636541;
    };

    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };
}
