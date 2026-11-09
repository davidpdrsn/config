{
  pkgs,
  piWrapped,
}:
pkgs.writeShellApplication {
  name = "pr-digest";
  runtimeInputs = [pkgs.gh piWrapped];
  text = ''
    export PYTHONIOENCODING=utf-8
    exec ${pkgs.python3}/bin/python3 ${../../../scripts/pr-digest.py} "$@"
  '';
}
