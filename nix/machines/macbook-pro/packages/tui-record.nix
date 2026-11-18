{pkgs, ...}:
pkgs.writeShellApplication {
  name = "tui-record";
  runtimeInputs = [
    pkgs.tmux
    pkgs.charm-freeze
    pkgs.ffmpeg
  ];
  text = ''
    exec ${pkgs.python3}/bin/python3 ${../../../../scripts/tui-record.py} "$@"
  '';
}
