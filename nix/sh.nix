{lib, config, ...}: let
  envVars = {
    EDITOR = "nvim";

    # required for go test containers to work with colima
    DOCKER_HOST = "unix:///Users/davidpdrsn/.colima/default/docker.sock";
    TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = "/var/run/docker.sock";

    GH_AUTH_TOKEN = "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";

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
    jll = "jj log -r 'root()..'";
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
    xtask = "cargo xtask";
    b = "/Users/davidpdrsn/code/dev-tools/cli/result/bin/t build";
    r = "/Users/davidpdrsn/code/dev-tools/cli/result/bin/t run";
    at = "tmux attach";
    godot = "/Applications/Godot_mono.app/Contents/MacOS/Godot";
    x = "/Users/davidpdrsn/code/bits-n-wires/x";
    blender = "/Applications/Blender.app/Contents/MacOS/Blender";
    ds = "/Users/davidpdrsn/code/dev-tools/cli/result/bin/t \"darwin-rebuild switch\"";
    dbui = "nvim +DBUI";
    claude-json = "claude --print --output-format json";
    claude-yolo = "claude --dangerously-skip-permissions";
    vi = "nvim";
    vim = "nvim";
    zz = "zellij";
  };
in {
  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/.bin"
  ];

  programs.nushell = {
    enable = true;
    settings = {
      show_banner = false;
    };
    shellAliases =
      {
        # nushell specific aliases
        v = "nvim";
        fg = "job unfreeze";
        g = "git log --decorate --oneline -20";
        l = "ls";
        la = "ls -la";
        o = "^open";
      }
      // shellAliases;
    environmentVariables = envVars;
    extraConfig = builtins.readFile ../jj/jj-completions.nu;
  };

  programs.zsh = {
    enable = true;
    initContent = builtins.readFile ../zsh/zshrc;
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
        l = "exa --long --header --git --all --sort name";
        o = "open .";
        la = "exa -a --long --header --sort name";
      }
      // shellAliases;
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = true;
      format = lib.concatStrings [
        "$directory"
        "\${custom.git_prompt}"
        "$line_break"
        "$character"
      ];
      right_format = lib.concatStrings [
        "$cmd_duration"
        "$nix_shell"
      ];
      custom = {
        git_prompt = {
          command = "git-prompt";
          format = "$output";
          when = true;
        };
      };
      directory = {
        fish_style_pwd_dir_length = 1;
        style = "white";
      };
      nix_shell = {
        format = "[$name]($style)";
      };
      rust = {
        format = "[$symbol($version)]($style)";
      };
      golang = {
        format = "[$symbol($version)]($style)";
      };
      nodejs = {
        format = "[$symbol($version)]($style)";
      };
    };
  };
}
