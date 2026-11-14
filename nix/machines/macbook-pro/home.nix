{
  config,
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
  # Mac-specific SSH: UseKeychain + colima
  programs.ssh.includes = ["${config.home.homeDirectory}/.colima/ssh_config"];
  programs.ssh.settings."*".UseKeychain = "yes";

  # Mac-specific env vars
  home.sessionVariables = {
    TERMINAL = "ghostty";
    # required for go test containers to work with colima
    DOCKER_HOST = "unix://${config.home.homeDirectory}/.colima/default/docker.sock";
    TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = "/var/run/docker.sock";
    NO_BG_TASKS = 1;
  };

  # Make user-local executables available in interactive shells and launchd jobs
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];

  # Make the shared agent skills available to Codex and Pi in every project on this Mac.
  home.file.".agents/skills".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/config/agents/skills";

  # Make the shared agent skills available to Claude Code in every project on this Mac.
  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/config/agents/skills";

  # Share one set of global instructions between Claude Code, Codex and Pi.
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/config/agents/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/config/agents/AGENTS.md";
  home.file.".pi/agent/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/config/agents/AGENTS.md";

  # GitButler checks Pi's own skill directory. Pi deduplicates the shared target.
  home.file.".pi/agent/skills/gitbutler".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/config/agents/skills/but";

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

  # Use the patched cargo in the GitButler checkout and its worktrees without
  # changing the repo. `use flake` prepends the dev shell to PATH, so the patched
  # cargo has to be added after it, hence the wrapper.
  programs.direnv.stdlib = ''
    if declare -F use_flake >/dev/null; then
      eval "_patched_cargo_$(declare -f use_flake)"

      use_flake() {
        _patched_cargo_use_flake "$@" || return

        case "$PWD/" in
          "${config.home.homeDirectory}/code/gitbutler/gitbutler-git/"* | "${config.home.homeDirectory}/.gitbutler-worktrees/gitbutler-git/"*)
            PATH_add "${config.home.homeDirectory}/.local/share/patched-cargo/bin"
            ;;
        esac
      }
    fi
  '';

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
