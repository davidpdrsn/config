{
  config,
  pkgs,
  ...
}: {
  home.sessionPath = ["/home/davidpdrsn/.local/bin"];

  programs.ssh.settings = {
    "github.com" = {
      User = "git";
      IdentityFile = "~/.ssh/github";
      IdentitiesOnly = true;
      AddKeysToAgent = "yes";
    };
  };

  services.ssh-agent.enable = true;

  xdg.configFile."mux/config.toml".source = (pkgs.formats.toml {}).generate "mux-config.toml" {
    layout = {
      tabbar = true;
      sidebar = false;
      agent_sidebar = false;
      sidebar_position = "left";
      agent_sidebar_position = "left";
    };
    # mux has no default bindings; everything after the prefix (ctrl+space) comes from here.
    keybinds = {
      "alt+j" = ["window" "focus" "--next" "--all"];
      "alt+k" = ["window" "focus" "--prev" "--all"];
      "alt+h" = ["window" "focus" "--prev"];
      "alt+l" = ["window" "focus" "--next"];
      "alt+shift+j" = ["project" "focus" "--next"];
      "alt+shift+k" = ["project" "focus" "--prev"];
      "alt+tab" = ["window" "focus" "--last"];

      "prefix+f" = ["window" "search"];
      "prefix+shift+f" = ["pane" "search"];

      "prefix+a" = ["agent" "sidebar" "focus"];
      "prefix+shift+a" = ["agent" "sidebar" "toggle"];

      "prefix+s" = ["sidebar" "focus"];
      "prefix+shift+s" = ["sidebar" "toggle"];

      "prefix+g" = ["agent" "search"];
      "prefix+space" = ["palette"];
      "prefix+r" = ["window" "rename"];
      "prefix+shift+r" = ["project" "rename"];
      "prefix+d" = ["detach"];
      "prefix+z" = ["pane" "zoom"];
      "prefix+w" = ["pane" "move"];
      "prefix+shift+w" = ["pane" "resize-mode"];

      "prefix+-" = ["pane" "split" "--direction" "down"];
      "prefix+\\" = ["pane" "split" "--direction" "right"];

      "prefix+n" = ["window" "new"];
      "prefix+j" = ["popup" "--" "but" "tui" "--remember-selection"];
      "prefix+shift+j" = ["pane" "split" "--direction" "right" "--no-focus" "--" "but" "tui" "--diff" "@"];
      "prefix+l" = ["window" "focus" "--last"];
      "prefix+;" = ["pane" "focus" "--last"];
      "prefix+=" = ["pane" "equalize"];
      "prefix+x" = ["pane" "close"];
      "prefix+shift+x" = ["window" "close"];
      "prefix+c" = ["pane" "edit-scrollback"];

      "prefix+1" = ["window" "focus" "--index" "1"];
      "prefix+2" = ["window" "focus" "--index" "2"];
      "prefix+3" = ["window" "focus" "--index" "3"];
      "prefix+4" = ["window" "focus" "--index" "4"];
      "prefix+5" = ["window" "focus" "--index" "5"];
      "prefix+6" = ["window" "focus" "--index" "6"];
      "prefix+7" = ["window" "focus" "--index" "7"];
      "prefix+8" = ["window" "focus" "--index" "8"];
      "prefix+9" = ["window" "focus" "--index" "9"];
      "prefix+0" = ["window" "focus" "--index" "10"];
    };
  };

  # Keep a mux server running so `ssh butbox` can always attach to it.
  # `mux server restart` hands over to a new `server run --wait` and exits, so
  # loop with `--wait` too: whichever process gets the socket lock serves, and
  # the other waits as a standby instead of failing.
  systemd.user.services.mux = {
    Unit.Description = "mux terminal multiplexer server";
    Service = {
      ExecStart = toString (pkgs.writeShellScript "mux-server" ''
        while true; do
          ${config.home.homeDirectory}/.cargo/bin/mux server run --wait
          sleep 1
        done
      '');
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = ["default.target"];
  };
}
