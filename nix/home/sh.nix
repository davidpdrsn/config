{
  lib,
  config,
  shell,
  pkgs,
  ...
}: let
  envVars = {
    TERMINAL = "ghostty";
    EDITOR = "nvim";
    SHELL = shell;

    # required for go test containers to work with colima
    DOCKER_HOST = "unix:///Users/davidpdrsn/.colima/default/docker.sock";
    TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = "/var/run/docker.sock";

    GH_AUTH_TOKEN = "***REMOVED***";

    BITS_N_WIRES_PLANE_API_KEY = "***REMOVED***";

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
    c = "clear";
    ca = "cargo";
    cat = "bat";
    dt = "cd ~/Desktop";
    diff = "diff --color";

    j = "jjui -revset \"present(@) | ancestors(immutable_heads().., 2) | present(trunk()) | ancestors(trunk(), 20)\"";
    jc = "jj commit";
    jd = "jj desc";
    jn = "jj new";
    jb = "jj bookmark";
    jp = "jj git push --all";
    jf = "jj git fetch";
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
    gl = "git log --graph --decorate --oneline -20";
    gll = "git log --graph --decorate --oneline";
    ggl = "git log --graph --decorate --oneline -20";
    ggll = "git log --graph --decorate --oneline";
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
    b = "t build";
    r = "t run";
    at = "tmux attach";
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

  home.sessionVariables = envVars;

  programs.nushell = {
    enable = true;
    settings = {
      show_banner = false;
    };
    shellAliases =
      {
        # nushell specific aliases
        v = "nvim";
        l = "ls";
        la = "ls -la";
        fg = "job unfreeze";
        o = "^open";
        vimconflicts = "zsh -c \"nvim $(t \\\"jj conflicting files\\\")\"";
      }
      // shellAliases;
    extraConfig = builtins.readFile ./../../jj/jj-completions.nu;
  };

  programs.fish = {
    enable = true;
    generateCompletions = true;
    shellAliases =
      {
        # fish specific aliases
        v = "nvim";
        l = "exa --long --header --git --all --sort name";
        la = "exa -a --long --header --sort name";
        o = "open .";
        # to not confuse claude-code
        ".." = "z ..";
        cd = "z";
      }
      // shellAliases;
  };

  programs.zsh = {
    enable = true;
    initContent = builtins.readFile ./../../zsh/zshrc;
    autosuggestion = {
      enable = true;
    };
    syntaxHighlighting = {
      enable = true;
    };
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
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      format = lib.concatStrings [
        "$directory"
        "\${custom.git_prompt}"
        "\${custom.jj_current_operation}"
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
        jj_current_operation = {
          command = "jj-current-operation";
          format = "[$output]($style)";
          when = true;
          detect_files = [".jj"];
          style = "yellow";
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
