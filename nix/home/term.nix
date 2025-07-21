{...}: {
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
        hide_when_typing = true;
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
}
