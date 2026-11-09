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
