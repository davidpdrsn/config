{pkgs}:
pkgs.writeShellApplication {
  name = "mail-me";
  runtimeInputs = [pkgs.msmtp];
  text = ''
    export PYTHONIOENCODING=utf-8
    exec ${pkgs.python3}/bin/python3 ${../../../scripts/mail-me.py} "$@"
  '';
}
