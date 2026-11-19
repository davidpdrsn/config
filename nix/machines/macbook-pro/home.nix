{
  config,
  lib,
  pkgs,
  ...
}: let
  # Use Core Audio directly: a default-device volume command could affect speakers
  # or the physical microphone instead. Build once, rather than compiling at login.
  unmuteBlackHole = pkgs.runCommandCC "unmute-blackhole" {} ''
    mkdir -p "$out/bin"
    $CC -Wall -Wextra -Werror -x c - -framework CoreAudio -framework CoreFoundation \
      -o "$out/bin/unmute-blackhole" <<'EOF'
    #include <CoreAudio/CoreAudio.h>
    #include <CoreFoundation/CoreFoundation.h>
    #include <stdbool.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <unistd.h>

    static bool unmute(void) {
      AudioObjectPropertyAddress property = {
        kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
      };
      UInt32 size = 0;
      if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &property,
                                        0, NULL, &size) != noErr || size == 0)
        return false;
      AudioDeviceID *devices = malloc(size);
      if (!devices) return false;
      if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &property,
                                     0, NULL, &size, devices) != noErr) {
        free(devices);
        return false;
      }
      AudioDeviceID target = kAudioObjectUnknown;
      for (UInt32 i = 0; i < size / sizeof(*devices); ++i) {
        AudioObjectPropertyAddress uidProperty = {
          kAudioDevicePropertyDeviceUID, kAudioObjectPropertyScopeGlobal,
          kAudioObjectPropertyElementMain
        };
        CFStringRef uid = NULL;
        UInt32 uidSize = sizeof(uid);
        OSStatus status = AudioObjectGetPropertyData(devices[i], &uidProperty,
                                                     0, NULL, &uidSize, &uid);
        if (status == noErr && uid) {
          if (CFEqual(uid, CFSTR("BlackHole2ch_UID"))) target = devices[i];
          CFRelease(uid);
        }
        if (target != kAudioObjectUnknown) break;
      }
      free(devices);
      if (target == kAudioObjectUnknown) return false;

      const AudioObjectPropertyScope scopes[] = {
        kAudioDevicePropertyScopeInput, kAudioDevicePropertyScopeOutput
      };
      for (unsigned i = 0; i < sizeof(scopes) / sizeof(*scopes); ++i) {
        AudioObjectPropertyAddress muteProperty = {
          kAudioDevicePropertyMute, scopes[i], kAudioObjectPropertyElementMain
        };
        UInt32 muted = 0;
        if (AudioObjectSetPropertyData(target, &muteProperty, 0, NULL,
                                      sizeof(muted), &muted) != noErr)
          return false;
        UInt32 muteSize = sizeof(muted);
        if (AudioObjectGetPropertyData(target, &muteProperty, 0, NULL,
                                      &muteSize, &muted) != noErr || muted != 0)
          return false;
      }
      return true;
    }

    int main(void) {
      // Core Audio or the Homebrew driver may not be ready at login.
      for (int attempt = 0; attempt < 15; ++attempt) {
        if (unmute()) {
          puts("BlackHole 2ch input and output are unmuted.");
          return EXIT_SUCCESS;
        }
        if (attempt < 14) sleep(2);
      }
      fputs("Could not find or unmute BlackHole 2ch after 15 attempts.\n", stderr);
      return EXIT_FAILURE;
    }
    EOF
  '';
in {
  imports = [./tailnet-sites.nix];

  # Mac-specific SSH: UseKeychain
  programs.ssh.settings."*".UseKeychain = "yes";

  # Mac-specific env vars
  home.sessionVariables = {
    TERMINAL = "ghostty";
    NO_BG_TASKS = 1;
    # The 1Password CLI uses the personal account unless told otherwise.
    OP_ACCOUNT = "my.1password.com";
  };

  # Make user-local executables available in interactive shells and launchd jobs
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];

  # Pi's system prompt is every .md file in agents/system, sorted by name and
  # joined with a blank line. This reads the working tree at switch time rather
  # than the flake source, because the flake only sees files git tracks, and a
  # new part should be included before it is committed.
  home.activation.piSystemPrompt = lib.hm.dag.entryAfter ["linkGeneration"] ''
    (
      export LC_ALL=C
      parts=("${config.home.homeDirectory}/config/agents/system"/*.md)
      dest="${config.home.homeDirectory}/.pi/agent/SYSTEM.md"
      tmp="$(mktemp)"
      ${pkgs.gawk}/bin/awk 'FNR == 1 && NR != 1 { print "" } { print }' "''${parts[@]}" > "$tmp"
      run mkdir -p "$(dirname "$dest")"
      # Remove first: an older generation linked this path into the repo.
      run rm -f "$dest"
      run mv "$tmp" "$dest"
    )
  '';

  home.file."Library/Application Support/gitbutler/programs.json".source =
    (pkgs.formats.json {}).generate
    "gitbutler-programs.json"
    (import ./gitbutler-programs.nix);

  # A locally patched cargo that garbage collects target directories. A dangling
  # link (it isn't built) is skipped by PATH lookup, which finds the flake's cargo.
  home.file.".local/share/patched-cargo/bin/cargo".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/code/cargo/target/release/cargo";

  # How long the patched cargo keeps build artifacts that no build has used.
  # Stock cargo ignores the setting.
  home.file.".cargo/config.toml".text = ''
    [cache.target-clean]
    max-age = "4 days"
  '';

  # Use the patched cargo in these projects, and in everything below them such
  # as worktrees, without changing the repos. `use flake` prepends the dev shell
  # to PATH, so the patched cargo has to be added after it, hence the wrapper.
  programs.direnv.stdlib = let
    patchedCargoDirs = [
      "code/gitbutler/gitbutler-git"
      ".gitbutler-worktrees/gitbutler-git"
      "code/foreverapp"
      "code/yet-another-slob-multiplexer"
      "code/agent"
      ".agent-worktrees/agent"
      # The fork itself. If a change breaks it, delete target/release/cargo
      # and the flake's cargo takes over.
      "code/cargo"
    ];
    patterns =
      lib.concatMapStringsSep " | "
      (dir: ''"${config.home.homeDirectory}/${dir}/"*'')
      patchedCargoDirs;
  in ''
    if declare -F use_flake >/dev/null; then
      eval "_patched_cargo_$(declare -f use_flake)"

      use_flake() {
        _patched_cargo_use_flake "$@" || return

        case "$PWD/" in
          ${patterns})
            PATH_add "${config.home.homeDirectory}/.local/share/patched-cargo/bin"
            ;;
        esac
      }
    fi
  '';

  # Records the size of every target dir once an hour, so that the Target GC
  # app's charts have history while the app isn't open. The app is built from
  # ~/code/cargo/target-gc-app and installed with `just install`.
  launchd.agents.target-gc-snapshot = {
    enable = true;
    config = {
      Label = "com.davidpdrsn.targetgc.snapshot";
      ProgramArguments = ["/Applications/Target GC.app/Contents/MacOS/TargetGC" "--snapshot"];
      StartInterval = 3600;
      RunAtLoad = true;
      ProcessType = "Background";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/target-gc-snapshot.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/target-gc-snapshot.err.log";
    };
  };

  # Mac-specific shell aliases
  programs.fish.shellAliases = {
    o = "open .";
  };

  # Mac-specific activation
  home.activation.createMacFolders = ''
    mkdir -p ~/Desktop/screenshots
    mkdir -p ~/code/dev-tools
    mkdir -p ~/Library/Logs
  '';

  # might have to run this once
  #   ssh-add --apple-use-keychain ~/.ssh/id_ed25519
  home.activation.addGithubKeyToKeychain = ''
    key="${config.home.homeDirectory}/.ssh/id_ed25519"
    if [ -f "$key" ]; then
      if [ -z "''${SSH_AUTH_SOCK:-}" ]; then
        export SSH_AUTH_SOCK="$(/bin/launchctl getenv SSH_AUTH_SOCK || true)"
      fi
      /usr/bin/ssh-add --apple-use-keychain "$key" >/dev/null 2>&1 || true
    fi
  '';

  # Once per login/load, not continuously: intentional muting still works.
  launchd.agents.unmute-blackhole = {
    enable = true;
    config = {
      Label = "com.davidpdrsn.unmute-blackhole";
      ProgramArguments = ["${unmuteBlackHole}/bin/unmute-blackhole"];
      RunAtLoad = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/unmute-blackhole.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/unmute-blackhole.err.log";
    };
  };

  launchd.agents.obsidian-auto-commit-push = {
    enable = true;
    config = {
      Label = "com.davidpdrsn.obsidian-auto-commit-push";
      ProgramArguments = [
        "/run/current-system/sw/bin/bash"
        "${config.home.homeDirectory}/config/scripts/obsidian-auto-commit-push"
      ];
      StartCalendarInterval = [
        {Minute = 0;}
        {Minute = 30;}
      ];
      RunAtLoad = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/obsidian-auto-commit-push.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/obsidian-auto-commit-push.err.log";
    };
  };

  programs.btop = {
    enable = true;
    # btop is installed in the system package set.
    package = null;
    settings.color_theme = "catppuccin_mocha";
  };

  xdg.configFile."btop/themes/catppuccin_mocha.theme".source = let
    theme = pkgs.catppuccin.override {
      variant = "mocha";
      themeList = ["btop"];
    };
  in "${theme}/btop/catppuccin_mocha.theme";

  programs.lazygit = {
    enable = true;
    settings = {
      # https://github.com/catppuccin/lazygit
      gui.theme = {
        activeBorderColor = ["#89b4fa" "bold"];
        inactiveBorderColor = ["#a6adc8"];
        optionsTextColor = ["#89b4fa"];
        selectedLineBgColor = ["#313244"];
        cherryPickedCommitBgColor = ["#45475a"];
        cherryPickedCommitFgColor = ["#89b4fa"];
        unstagedChangesColor = ["#f38ba8"];
        defaultFgColor = ["#cdd6f4"];
        searchingActiveBorderColor = ["#f9e2af"];
      };
    };
  };
}
