{
  lib,
  pkgs,
  config,
  ...
}: {
  programs.git = {
    enable = true;
    lfs = {
      enable = true;
    };
    ignores = [
      "*.swp"
      "*.blend1"
      ".DS_Store"
      "/tags"
      ".sass-cache"
      "xterm-256color.ti"
      "screen-256color.ti"
      "tags.lock"
      "tags.temp"
      "target/"
      "result"
      "rusty-tags.vi"
      ".metals"
      ".bloop"
      ".jvmopts"
      ".bsp"
      "project/project/"
      ".vim"
      "dump.rdb"
      "/tmp"
      "bacon.toml"
      ".reload-on-demand.toml"
      ".temp"
      ".tmp"
      ".direnv"
      ".claude/settings.local.json"
      ".cache"
      ".jj"
      ".worktrees"
      ".worktreeinclude"
      "**/.pi/tmp/"
      "**/.pi/suggester"
      ".pi/skills/but"
      ".pi/skills/committing"
    ];
    settings =
      {
        credential.helper = "!${pkgs.gh}/bin/gh auth git-credential";
        alias = {
          wt = "worktree";
        };
        user =
          {
            name = "David Pedersen";
            email = "david.pdrsn@gmail.com";
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
            signingkey = "${config.home.homeDirectory}/.ssh/id_ed25519_signing.pub";
          };
        init = {
          defaultBranch = "main";
        };
        push = {
          autoSetupRemote = "true";
        };
        rebase = {
          updateRefs = true;
        };
        rerere = {
          enabled = true;
        };
        fetch = {
          prune = true;
        };
        merge = {
          conflictStyle = "zdiff3";
        };
        diff = {
          algorithm = "histogram";
        };
        commit =
          {
            verbose = true;
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
            gpgsign = true;
          };
        branch = {
          sort = "-committerdate";
        };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        gpg = {
          format = "ssh";
          ssh = {
            allowedSignersFile = "${config.home.homeDirectory}/.config/git/allowed_signers";
          };
        };
        gitbutler = {
          signCommits = true;
        };
      };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      line-numbers = true;
      side-by-side = false;
    };
  };

  programs.jujutsu = {
    enable = true;
    settings.user = {
      email = "david.pdrsn@gmail.com";
      name = "David Pedersen";
    };
  };
}
