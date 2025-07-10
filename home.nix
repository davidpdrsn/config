{
  config,
  lib,
  ...
}: let
  envVars = {
    EDITOR = "nvim";

    # required for go test containers to work with colima
    DOCKER_HOST = "unix:///Users/davidpdrsn/.colima/default/docker.sock";
    TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = "/var/run/docker.sock";

    BITS_N_WIRES_PLANE_API_KEY = "***REMOVED***";
    BLENDER_PATH = "/Applications/Blender.app/Contents/MacOS/Blender";
    GODOT_PATH = "/Applications/Godot_mono.app/Contents/MacOS/Godot";

    LUN_DEV_DB_PASS = "***REMOVED***";
    LUN_PROD_DB_PASS = "***REMOVED***";

    # lun org keys
    ANTHROPIC_API_KEY = "***REMOVED***";
    GEMINI_API_KEY = "***REMOVED***";

    TERM = "tmux-256color";

    CARGO_PROFILE_DEV_SPLIT_DEBUGINFO = "unpacked";
    CARGO_PROFILE_TEST_SPLIT_DEBUGINFO = "unpacked";
    CARGO_INCREMENTAL = 1;
    CARGO_UNSTABLE_SPARSE_REGISTRY = "true";
    CARGO_TERM_COLOR = "always";
  };
  shellAliases = {
    # aliases that work in all shells
    ".." = "z ..";
    c = "clear";
    ca = "cargo";
    cd = "z";
    cat = "bat";
    dt = "cd ~/Desktop";
    diff = "diff --color";
    j = "jj";
    jd = "jj desc";
    jn = "jj new";
    jp = "jj git push";
    jpll = "jj git pull";
    gaa = "git add --all";
    gap = "git add -p";
    gb = "git branch";
    gc = "git commit --verbose";
    gco = "git checkout";
    gcob = "git checkout -b";
    gcof = "git-branch-picker checkout";
    gmf = "git-branch-picker merge";
    git-cargo-lock-conflict = "git checkout main -- Cargo.lock";
    gl = "git log --decorate --oneline -20";
    gll = "git log --decorate --oneline";
    ggl = "git log --decorate --oneline -20";
    ggll = "git log --decorate --oneline";
    gp = "git push";
    gpf = "git push --force-with-lease";
    gd = "git diff";
    d = "git diff";
    gdc = "git diff --cached";
    gr = "git reset";
    grh = "git reset --hard";
    grs = "git reset --soft";
    gca = "git commit --amend --verbose";
    gpll = "git pull";
    ga = "git add";
    grb = "git rebase";
    gm = "git merge";
    grbc = "git rebase --continue";
    grba = "git rebase --abort";
    grbi = "git rebase -i";
    gs = "git show";
    l = "exa --long --header --git --all --sort name";
    la = "exa -a --long --header --sort name";
    xtask = "cargo xtask";
    o = "open .";
    b = "/Users/davidpdrsn/.cargo/bin/t build";
    r = "/Users/davidpdrsn/.cargo/bin/t run";
    at = "tmux attach";
    godot = "/Applications/Godot_mono.app/Contents/MacOS/Godot";
    x = "/Users/davidpdrsn/code/bits-n-wires/x";
    blender = "/Applications/Blender.app/Contents/MacOS/Blender";
    ds = "t \"darwin-rebuild switch\"";
    dbui = "nvim +DBUI";
    claude-json = "claude --print --output-format json";
    claude-yolo = "claude --dangerously-skip-permissions";
    vi = "nvim";
    vim = "nvim";
  };
in {
  # Don't change this value, even when updating home-manager.
  home.stateVersion = "25.05";

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
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

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        email = "david.pdrsn@gmail.com";
        name = "David Pedersen";
      };
      ui = {
        default-command = "log";
        pager = ":builtin";
      };
      colors = {
        "diff token" = {underline = false;};
        "diff removed token" = {bg = "#221111";};
        "diff added token" = {bg = "#002200";};
      };
    };
  };

  programs.zellij = {
    enable = true;
  };

  programs.neovim = {
    enable = true;
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/.bin"
  ];

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      format = lib.concatStrings [
        "$directory"
        "$custom.git_prompt"
        "$line_break"
        "$character"
      ];
      right_format = lib.concatStrings [
        "$nix_shell"
      ];
      custom = {
        git_prompt = {
          command = "git-prompt";
          format = "$output";
          when = true;
        };
      };
      nix_shell = {
        symbol = "";
      };
    };
  };

  programs.nushell = {
    enable = true;
    settings = {
      show_banner = false;
      # completions.external = {
      #   enable = true;
      #   max_results = 200;
      # };
    };
    shellAliases =
      {
        # nushell specific aliases
        v = "nvim";
        fg = "job unfreeze";
        g = "git log --decorate --oneline -20";
      }
      // shellAliases;
    environmentVariables = envVars;
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
    sessionVariables = envVars;
    shellAliases =
      {
        # zsh specific aliases
        ea = "cd ~/config && nvim ~/config/configuration.nix";
        format-lua = "stylua --config-path ~/.stylua.toml $(fd .lua)";
        vimconflicts = "nvim $(rg -l -. \"[<>=]{7}\")";
        gcai = "git commit --verbose -e -m \"$(git-diff-ai-summarize)\"";
        vv = "nvim $(rg --files | fzf)";
        mkdir = "mkdir -p";
      }
      // shellAliases;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
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
      "--glob=!.jj/*"
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
    ".config/zellij/config.kdl".source = ./zellij/config.kdl;
    ".stylua.toml".source = ./stylua/stylua.toml;
  };

  programs.alacritty = {
    enable = true;
    theme = "catppuccin_mocha";
    settings = {
      general = {
        working_directory = "/Users/davidpdrsn/config/";
      };
      terminal = {
        shell = {
          program = "/bin/zsh";
          args = ["-l" "-c" "exec nu"];
        };
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

    if [ ! -e ~/.config/ghostty ]; then
      ln -s ~/config/ghostty ~/.config
    fi

    mkdir -p ~/Desktop/screenshots
    mkdir -p ~/code/dev-tools
  '';
}
