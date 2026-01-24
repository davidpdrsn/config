{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with pkgs;
    [
      bat
      cargo-limit
      cargo-outdated
      cargo-watch
      curl
      eza
      fd
      ffmpeg
      fzf
      gh
      htop
      imagemagick
      jjui
      jq
      mergiraf
      ruby_3_4
      stylua
      tokei
      tree
      watchexec
      wget
      openai-whisper
      yt-dlp
      hyperfine
      nxv
      resvg

      claude-code
      codex
      opencode

      colima
      docker

      alejandra # nix formatter
      nil # nix language server

      autoraise
      mas
    ]
    ++ map (pkg: inputs.${pkg}.packages.${pkgs.stdenv.hostPlatform.system}.default)
    [
      "smart-pwd-2"
      "is-vim-running"
      "git-remove-merged-branches"
      "replace"
      "remove-indentation"
      "git-branch-picker"
      "go-insert-error"
      "git-history-csv"
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
