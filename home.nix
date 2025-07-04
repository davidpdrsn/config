{pkgs, ...}: {
  # Don't change this value, even when updating home-manager.
  home.stateVersion = "25.05";

  programs.zoxide.enable = true;

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.git = {
    enable = true;
    aliases = {
      wt = "worktree";
    };
    extraConfig = {
      user = {
        name = "David Pedersen";
        email = "david.pdrsn@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };
      push = {
        autoSetupRemote = "true";
      };
      "filter \"lfs\"" = {
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = "true";
        clean = "git-lfs clean -- %f";
      };
    };
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
      "target"
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
      "__debug_bin*"
      ".direnv"
      ".claude"
    ];
    delta = {
      enable = true;
      options = {
        line-numbers = true;
        side-by-side = false;
      };
    };
  };

  programs.zsh = {
    enable = true;
    initContent = builtins.readFile ./zsh/zshrc;
    autosuggestion = {
      enable = true;
    };
    syntaxHighlighting = {
      enable = true;
    };
    sessionVariables = {
      EDITOR = "nvim";

      # required for go test containers to work with colima
      DOCKER_HOST = "unix:///Users/davidpdrsn/.colima/default/docker.sock";
      TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = "/var/run/docker.sock";

      BITS_N_WIRES_PLANE_API_KEY = "plane_api_ed28cd5eb1304b3eb9607b5a52c11bbd";
      BLENDER_PATH = "/Applications/Blender.app/Contents/MacOS/Blender";
      GODOT_PATH = "/Applications/Godot_mono.app/Contents/MacOS/Godot";

      LUN_DEV_DB_PASS = "p!G-inYH3ZxW";
      LUN_PROD_DB_PASS = "G5_t;(CU;)uoqUmQ";

      # lun org keys
      ANTHROPIC_API_KEY = "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";
      GEMINI_API_KEY = "AIzaSyA3yQ94vd6WwJSNVOK4dNwXSdojhPzJlRo";

      TERM = "tmux-256color";

      CARGO_PROFILE_DEV_SPLIT_DEBUGINFO = "unpacked";
      CARGO_PROFILE_TEST_SPLIT_DEBUGINFO = "unpacked";
      CARGO_INCREMENTAL = 1;
      CARGO_UNSTABLE_SPARSE_REGISTRY = "true";
      CARGO_TERM_COLOR = "always";
    };
    shellAliases = {

    };
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      enter_accept = false;
    };
  };

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ./tmux/tmux.conf;
  };

  programs.ripgrep = {
    enable = true;
    arguments = [
      # Search hidden files / directories (e.g. dotfiles) by default
      "--hidden"
      # Search files in .gitignore
      "--no-ignore"
      # Using glob patterns to include/exclude files or folders
      "--glob=!.git/*"
      "--glob=!node_modules"
      "--glob=!.godot/*"
      "--glob=!build"
      "--glob=!builds"
      "--glob=!.cache"
      "--glob=!.go"
      "--glob=!.direnv"
      "--glob=!.pnpm-global"
      "--glob=!temp"
      "--glob=!*\.map"
      "--glob=!target"
      "--glob=!*\.log"
      "--glob=!*\.DS_Store"
      "--glob=!*\.js"
      "--glob=!*\.d\.ts"
      # Because who cares about case!?
      "--smart-case"
    ];
  };

  home.file = {
    ".bin".source = ./bin;
    ".config/balance/config.toml".source = ./balance/balance.toml;
    ".stylua.toml".source = ./stylua/stylua.toml;
  };

  programs.alacritty = {
    enable = true;
    theme = "catppuccin_mocha";
    settings = {
      general = {
        working_directory = "/Users/davidpdrsn/config/";
      };
      window = {
        padding = {
          x = 3;
          y = 3;
        };
      };
      font = {
        normal = {
          family = "Iosevka Nerd Font Mono";
          style = "Light";
        };
        bold = {
          family = "Iosevka Nerd Font Mono";
          style = "Light";
        };
        italic = {
          family = "Iosevka Nerd Font Mono";
          style = "Light";
        };
        size = 13;
      };
      mouse = {
        hide_when_typing = false;
      };
      keyboard = {
        bindings = [
          {
            key = "Enter";
            mods = "Command";
            action = "ToggleSimpleFullscreen";
          }
        ];
      };
    };
  };

  programs.home-manager.enable = true;

  home.activation.createFolders = ''
    mkdir -p ~/.config

    mkdir -p .config/cli
    touch .config/cli/history

    if [ ! -e ~/.config/nvim ]; then
      ln -s ~/config/nvim ~/.config
    fi

    mkdir -p ~/Desktop/screenshots
    mkdir -p ~/code/dev-tools
  '';
}
