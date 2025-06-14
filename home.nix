{ pkgs, ... }:

{
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
        includes = [{ path = "~/config/git/gitconfig"; }];
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
    };

    programs.atuin = {
        enable = true;
        enableZshIntegration = true;
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
            "--glob=!temp"
            "--glob=!*\.map"
            "--glob=!target"
            "--glob=!*\.log"
            "--glob=!*\.DS_Store"
            # Because who cares about case!?
            "--smart-case"
        ];
    };

    home.file = {
        ".gitignoreglobal".source = ./gitignoreglobal;
        ".bin".source = ./bin;
        ".config/ghostty".source = ./ghostty;
    };

    programs.home-manager.enable = true;
}
